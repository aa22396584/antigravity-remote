import 'dart:async';
import 'dart:typed_data';
import '../models/instance_info.dart';
import 'cloud_relay_client.dart';
import 'endpoints.dart';
import 'transport_interface.dart';
import 'webrtc_mesh_client.dart';

/// 當非冪等操作在傳輸層已送出 (In-flight) 但確認失敗時拋出，防止自動重送造成重複寫入 (P0 #3)
class DuplicateExecutionPreventedException implements Exception {
  final String rpcPath;
  final Object cause;

  const DuplicateExecutionPreventedException({
    required this.rpcPath,
    required this.cause,
  });

  @override
  String toString() =>
      '非冪等請求已發送至 P2P 但確認失敗或逾時 ($rpcPath)。已阻止自動切換中繼重送以防止重複執行，請手動重試: $cause';
}

class DualTransportManager {
  final CloudRelayClient relayClient;
  final WebRtcMeshClient? meshClient;

  final _transportController = StreamController<TransportType>.broadcast();
  final _latencyController = StreamController<int>.broadcast();

  TransportType _currentTransport = TransportType.relay;
  int? _currentLatencyMs;
  StreamSubscription? _relayLatencySub;
  StreamSubscription? _meshLatencySub;
  StreamSubscription? _meshConnSub;

  DualTransportManager({
    required this.relayClient,
    this.meshClient,
  }) {
    _init();
  }

  TransportType get currentTransport => _currentTransport;
  int? get currentLatencyMs => _currentLatencyMs;
  Stream<TransportType> get transportStream => _transportController.stream;
  Stream<int> get latencyStream => _latencyController.stream;

  void _init() {
    _relayLatencySub = relayClient.latencyStream.listen((lat) {
      if (_currentTransport == TransportType.relay) {
        _currentLatencyMs = lat;
        if (!_latencyController.isClosed) {
          _latencyController.add(lat);
        }
      }
    });

    if (meshClient != null) {
      _meshConnSub = meshClient!.connectionStatusStream.listen((isConnected) {
        if (isConnected) {
          _setTransport(TransportType.p2p);
          if (meshClient!.currentLatencyMs != null) {
            _currentLatencyMs = meshClient!.currentLatencyMs;
            if (!_latencyController.isClosed) {
              _latencyController.add(_currentLatencyMs!);
            }
          }
        } else if (_currentTransport == TransportType.p2p) {
          _setTransport(TransportType.relay);
          if (relayClient.currentLatencyMs != null) {
            _currentLatencyMs = relayClient.currentLatencyMs;
            if (!_latencyController.isClosed) {
              _latencyController.add(_currentLatencyMs!);
            }
          }
        }
      });

      _meshLatencySub = meshClient!.latencyStream.listen((lat) {
        if (meshClient!.isConnected) {
          if (_currentTransport != TransportType.p2p) {
            _setTransport(TransportType.p2p);
          }
          _currentLatencyMs = lat;
          if (!_latencyController.isClosed) {
            _latencyController.add(lat);
          }
        }
      });
    }
  }

  Future<void> connectAll() async {
    // 1. 先連通 Cloud Relay 作為保底
    await relayClient.connect();
    _setTransport(TransportType.relay);

    // 2. 背景嘗試發起 WebRTC P2P 網狀連線
    if (meshClient != null) {
      unawaited(_attemptMeshUpgrade());
    }
  }

  Future<void> _attemptMeshUpgrade() async {
    try {
      await meshClient!.connect();
      if (meshClient!.isConnected) {
        _setTransport(TransportType.p2p);
      }
    } catch (_) {
      // 若 P2P 協商失敗或逾時，繼續保留 Cloud Relay
      _setTransport(TransportType.relay);
    }
  }

  void _setTransport(TransportType type) {
    _currentTransport = type;
    if (!_transportController.isClosed) {
      _transportController.add(type);
    }
  }

  /// 判定特定 RPC 是否具備冪等性 (Idempotent)
  static bool isRpcPathIdempotent(String rpcPath) {
    if (rpcPath == ApiEndpoints.sendUserCascadeMessage ||
        rpcPath == ApiEndpoints.sendTerminalInput ||
        rpcPath == ApiEndpoints.handleCascadeUserInteraction ||
        rpcPath == ApiEndpoints.writeFile) {
      return false;
    }
    if (rpcPath == ApiEndpoints.listInstances ||
        rpcPath == ApiEndpoints.listConversations ||
        rpcPath == ApiEndpoints.readFile) {
      return true;
    }
    // 預設檢驗動詞關鍵字
    final lower = rpcPath.toLowerCase();
    if (lower.contains('send') ||
        lower.contains('handle') ||
        lower.contains('execute') ||
        lower.contains('write') ||
        lower.contains('delete') ||
        lower.contains('remove') ||
        lower.contains('create') ||
        lower.contains('update')) {
      return false;
    }
    return true;
  }

  /// 智慧自適應呼叫（優先 P2P，Fallback Cloud Relay；非冪等請求在 in-flight 失敗時禁止自動重送）
  Future<Uint8List> callUnary(
    String rpcPath,
    Uint8List payload, {
    bool? isIdempotent,
  }) async {
    final idempotent = isIdempotent ?? isRpcPathIdempotent(rpcPath);

    if (meshClient != null && meshClient!.isConnected) {
      try {
        final result = await meshClient!.callUnary(rpcPath, payload);
        if (_currentTransport != TransportType.p2p) {
          _setTransport(TransportType.p2p);
        }
        return result;
      } on PreFlightException {
        // 根本未送出至網路線路，切換為中繼並安全重試（即使非冪等操作也不會造成重複執行）
        _setTransport(TransportType.relay);
        return relayClient.callUnary(rpcPath, payload);
      } on InFlightRpcException catch (e) {
        // P2P 呼叫已在途中 (in-flight)。若為非冪等性請求，嚴禁自動透過 Relay 重送！(P0 #3)
        _setTransport(TransportType.relay);
        if (!idempotent) {
          throw DuplicateExecutionPreventedException(
            rpcPath: rpcPath,
            cause: e.cause,
          );
        }
        // 冪等性請求方可安全回退 Relay 重試
        return relayClient.callUnary(rpcPath, payload);
      } on RpcException {
        // 對端明確回傳業務錯誤，直接拋出，不觸發重複重試
        rethrow;
      } catch (e) {
        // 其他未知異常（防禦性處理）
        _setTransport(TransportType.relay);
        if (!idempotent) {
          throw DuplicateExecutionPreventedException(
            rpcPath: rpcPath,
            cause: e,
          );
        }
        return relayClient.callUnary(rpcPath, payload);
      }
    }

    _setTransport(TransportType.relay);
    return relayClient.callUnary(rpcPath, payload);
  }

  /// 串流式呼叫（優先 P2P，Fallback Cloud Relay）
  Stream<Uint8List> callStream(String rpcPath, Uint8List payload) {
    if (meshClient != null && meshClient!.isConnected) {
      try {
        return meshClient!.callStream(rpcPath, payload);
      } catch (_) {
        _setTransport(TransportType.relay);
        return relayClient.callStream(rpcPath, payload);
      }
    }

    _setTransport(TransportType.relay);
    return relayClient.callStream(rpcPath, payload);
  }

  Future<void> disconnect() async {
    _relayLatencySub?.cancel();
    _meshLatencySub?.cancel();
    _meshConnSub?.cancel();
    await relayClient.disconnect();
    await meshClient?.disconnect();
    _setTransport(TransportType.offline);
  }

  Future<void> dispose() async {
    await disconnect();
    if (!_transportController.isClosed) {
      await _transportController.close();
    }
    if (!_latencyController.isClosed) {
      await _latencyController.close();
    }
    relayClient.dispose();
    meshClient?.dispose();
  }
}
