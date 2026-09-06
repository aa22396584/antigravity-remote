import 'dart:async';
import 'dart:typed_data';
import '../models/instance_info.dart';
import 'cloud_relay_client.dart';
import 'webrtc_mesh_client.dart';

class DualTransportManager {
  final CloudRelayClient relayClient;
  final WebRtcMeshClient? meshClient;

  final _transportController = StreamController<TransportType>.broadcast();
  final _latencyController = StreamController<int>.broadcast();

  TransportType _currentTransport = TransportType.relay;
  int? _currentLatencyMs;
  StreamSubscription? _relayLatencySub;
  StreamSubscription? _meshLatencySub;

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
      _meshLatencySub = meshClient!.latencyStream.listen((lat) {
        if (_currentTransport == TransportType.p2p) {
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

  /// 智慧自適應呼叫（優先 P2P，Fallback Cloud Relay）
  Future<Uint8List> callUnary(String rpcPath, Uint8List payload) async {
    if (meshClient != null && meshClient!.isConnected) {
      try {
        final result = await meshClient!.callUnary(rpcPath, payload);
        if (_currentTransport != TransportType.p2p) {
          _setTransport(TransportType.p2p);
        }
        return result;
      } catch (_) {
        // P2P 失敗時自動 Fallback
        _setTransport(TransportType.relay);
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
