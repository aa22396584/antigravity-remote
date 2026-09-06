import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import '../models/instance_info.dart';
import 'ecdsa_p256_service.dart';
import 'endpoints.dart';
import 'transport_interface.dart';

/// 訊框封包模型
class FramePacket {
  final int flag;
  final Uint8List payload;

  const FramePacket({required this.flag, required this.payload});
}

/// WebRTC SCTP 封包分片 (Fragmentation) 與沾黏封包 (Sticky packets) 累積解析緩衝區
class FrameAccumulator {
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  /// 加入收到的網路資料分片
  void push(Uint8List chunk) {
    if (chunk.isNotEmpty) {
      _buffer.add(chunk);
    }
  }

  /// 提取所有已完整組裝的訊框 (5-byte 前綴: [1B flag] [4B length] [payload])
  List<FramePacket> drainFrames() {
    final bytes = _buffer.takeBytes();
    if (bytes.isEmpty) return const [];

    final frames = <FramePacket>[];
    int offset = 0;
    final totalLen = bytes.length;

    while (offset + 5 <= totalLen) {
      final flag = bytes[offset];
      final length = (bytes[offset + 1] << 24) |
          (bytes[offset + 2] << 16) |
          (bytes[offset + 3] << 8) |
          bytes[offset + 4];

      // 防禦性檢查：防長度溢位或負數異常
      if (length < 0) {
        offset += 1;
        continue;
      }

      final frameEnd = offset + 5 + length;
      if (frameEnd <= totalLen) {
        // 取得完整訊框 Payload
        final payload = Uint8List.sublistView(bytes, offset + 5, frameEnd);
        frames.add(FramePacket(flag: flag, payload: payload));
        offset = frameEnd;
      } else {
        // 封包尚未完整，保留待後續 SCTP 分片送達
        break;
      }
    }

    // 若有剩餘未組裝完成的殘留分片，存回緩衝區
    if (offset < totalLen) {
      _buffer.add(Uint8List.sublistView(bytes, offset, totalLen));
    }

    return frames;
  }

  /// 清空累積器緩衝
  void clear() {
    _buffer.clear();
  }

  /// 當前緩衝中的位元組數
  int get bufferedBytes => _buffer.length;
}

class WebRtcMeshClient implements TransportClient {
  static const int signalingPollTimeoutSeconds = 30;

  final String baseUrl;
  final String googleAccessToken;
  final String targetInstanceUuid;
  final String clientInstanceId;
  final http.Client _httpClient;

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  RTCDataChannel? _cascadeDataChannel;
  RTCDataChannel? _terminalDataChannel;

  final FrameAccumulator _proxyAccumulator = FrameAccumulator();
  final FrameAccumulator _cascadeAccumulator = FrameAccumulator();
  final FrameAccumulator _terminalAccumulator = FrameAccumulator();

  EcdsaP256Service? _cryptoService;
  Timer? _signalingTimer;

  bool _isChannelAuthenticated = false;
  int? _lastLatencyMs;
  final _latencyController = StreamController<int>.broadcast();

  // 獨立隔離串流控制器：徹底杜絕 Cascade Reactive Updates 與 Terminal Output 污染
  final _cascadeStreamController = StreamController<Uint8List>.broadcast();
  final _terminalStreamController = StreamController<Uint8List>.broadcast();
  final _defaultStreamController = StreamController<Uint8List>.broadcast();

  final Map<int, Completer<Uint8List>> _pendingRequests = {};
  int _requestIdCounter = 1;

  WebRtcMeshClient({
    required this.baseUrl,
    required this.googleAccessToken,
    required this.targetInstanceUuid,
    String? clientInstanceId,
    http.Client? httpClient,
  })  : clientInstanceId = clientInstanceId ??
            'flutter-remote-${DateTime.now().millisecondsSinceEpoch}',
        _httpClient = httpClient ?? http.Client();

  @override
  TransportType get transportType => TransportType.p2p;

  @override
  bool get isConnected =>
      ((_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) ||
          (_cascadeDataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) ||
          (_terminalDataChannel?.state == RTCDataChannelState.RTCDataChannelOpen)) &&
      _isChannelAuthenticated;

  @override
  Stream<int> get latencyStream => _latencyController.stream;

  @override
  int? get currentLatencyMs => _lastLatencyMs;

  @override
  Future<void> connect() async {
    try {
      // 1. 生成 ECDSA P-256 密鑰對 (純 Dart 跨平台保證)
      _cryptoService = EcdsaP256Service.generate();
      final pubKeyBase64 = _cryptoService!.getSpkiPublicKeyBase64();

      // 2. 向雲端宣告 Session (InitiateMeshSession)
      final initUrl = Uri.parse('$baseUrl${ApiEndpoints.initiateMeshSession}');
      final initResp = await _httpClient.post(
        initUrl,
        headers: {
          'Authorization': 'Bearer $googleAccessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'target_instance_id': targetInstanceUuid,
          'client_instance_id': clientInstanceId,
          'web_crypto_pub_key': pubKeyBase64,
        }),
      );

      if (initResp.statusCode != 200) {
        throw Exception(
          'InitiateMeshSession failed: ${initResp.statusCode} - ${initResp.body}',
        );
      }

      final initData = jsonDecode(initResp.body) as Map<String, dynamic>;
      final sessionId = initData['session_id'] as String? ?? '';
      final rawStun = (initData['stun_servers'] as List<dynamic>?) ?? [];
      final stunServers = rawStun.map((e) => e.toString()).toList();
      if (stunServers.isEmpty) {
        stunServers.add(ApiEndpoints.defaultStunServer);
      }

      // 3. 建立 RTCPeerConnection
      final rtcConfig = {
        'iceServers': stunServers.map((s) => {'urls': s}).toList(),
      };
      _peerConnection = await createPeerConnection(rtcConfig);

      // 【C-05】補齊本機 ICE Candidate 即時上報
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) async {
        if (candidate.candidate == null || candidate.candidate!.isEmpty) return;
        try {
          final sendSignalingUrl =
              Uri.parse('$baseUrl${ApiEndpoints.sendSignalingMessage}');
          await _httpClient.post(
            sendSignalingUrl,
            headers: {
              'Authorization': 'Bearer $googleAccessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'session_id': sessionId,
              'payload': jsonEncode({
                'type': 'candidate',
                'candidate': {
                  'candidate': candidate.candidate,
                  'sdpMid': candidate.sdpMid,
                  'sdpMLineIndex': candidate.sdpMLineIndex,
                },
              }),
              'payload_type': 'candidate',
            }),
          );
        } catch (_) {
          // 暫態候選上報失敗忽略
        }
      };

      // 4. 建立 DataChannels (提供獨立專屬頻道多工與單頻道 Flag 多工雙保險)
      final dcInit = RTCDataChannelInit()..ordered = true;
      _dataChannel = await _peerConnection!.createDataChannel(
        'proxy-channel',
        dcInit,
      );
      _setupDataChannelListeners(_dataChannel!, 'proxy-channel', _proxyAccumulator);

      _cascadeDataChannel = await _peerConnection!.createDataChannel(
        'cascade-channel',
        dcInit,
      );
      _setupDataChannelListeners(_cascadeDataChannel!, 'cascade-channel', _cascadeAccumulator);

      _terminalDataChannel = await _peerConnection!.createDataChannel(
        'terminal-channel',
        dcInit,
      );
      _setupDataChannelListeners(_terminalDataChannel!, 'terminal-channel', _terminalAccumulator);

      // 監聽對端反向建立之 DataChannel
      _peerConnection!.onDataChannel = (RTCDataChannel channel) {
        if (channel.label == 'cascade-channel') {
          _cascadeDataChannel = channel;
          _setupDataChannelListeners(channel, 'cascade-channel', _cascadeAccumulator);
        } else if (channel.label == 'terminal-channel') {
          _terminalDataChannel = channel;
          _setupDataChannelListeners(channel, 'terminal-channel', _terminalAccumulator);
        } else {
          _dataChannel = channel;
          _setupDataChannelListeners(
            channel,
            channel.label ?? 'proxy-channel',
            _proxyAccumulator,
          );
        }
      };

      // 5. 建立 SDP Offer 並發送至信令伺服器
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      final sendSignalingUrl =
          Uri.parse('$baseUrl${ApiEndpoints.sendSignalingMessage}');
      await _httpClient.post(
        sendSignalingUrl,
        headers: {
          'Authorization': 'Bearer $googleAccessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'session_id': sessionId,
          'payload': jsonEncode({'type': 'offer', 'sdp': offer.sdp}),
          'payload_type': 'offer',
        }),
      );

      // 6. 輪詢桌面端回傳之 SDP Answer（具備超時機制）
      _startSignalingPoll(sessionId);
    } catch (e) {
      _isChannelAuthenticated = false;
      rethrow;
    }
  }

  void _setupDataChannelListeners(
    RTCDataChannel dc,
    String channelLabel,
    FrameAccumulator accumulator,
  ) {
    dc.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        // DataChannel 已連通
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        if (channelLabel == 'proxy-channel') {
          _isChannelAuthenticated = false;
        }
      }
    };

    dc.onMessage = (RTCDataChannelMessage msg) async {
      if (msg.isBinary) {
        accumulator.push(msg.binary);
        final frames = accumulator.drainFrames();
        for (final frame in frames) {
          await _routeFrame(frame, fromChannel: channelLabel);
        }
      }
    };
  }

  /// 處理 5-byte 分幀、Channel Binding 驗證與 RPC / 串流多工分流
  Future<void> _routeFrame(FramePacket frame, {String? fromChannel}) async {
    final payload = frame.payload;
    final flag = frame.flag;

    // 1. 檢查是否為 Channel Binding Challenge 握手挑戰
    if (!_isChannelAuthenticated) {
      try {
        final challengeJson = jsonDecode(utf8.decode(payload));
        if (challengeJson is Map && challengeJson['challenge_nonce'] != null) {
          await _respondToChannelBindingChallenge(
            challengeJson['challenge_nonce'] as String,
          );
          _isChannelAuthenticated = true;
          _lastLatencyMs = 12; // Initial P2P estimate
          if (!_latencyController.isClosed) {
            _latencyController.add(_lastLatencyMs!);
          }
          return;
        }
      } catch (_) {
        // Non-JSON, proceed to standard dispatch
      }
    }

    // 2. 一元 RPC 請求回傳匹配
    if (flag == 0x00 && _pendingRequests.isNotEmpty) {
      final firstKey = _pendingRequests.keys.first;
      final completer = _pendingRequests.remove(firstKey);
      completer?.complete(payload);
      return;
    }

    // 3. 多工隔離分流 (Multiplexing Isolation)
    // 優先根據獨立 DataChannel 頻道標籤或 5-byte Flag (0x01: Cascade, 0x02: Terminal)
    if (fromChannel == 'terminal-channel' || flag == 0x02) {
      if (!_terminalStreamController.isClosed) {
        _terminalStreamController.add(payload);
      }
      return;
    }

    if (fromChannel == 'cascade-channel' || flag == 0x01) {
      if (!_cascadeStreamController.isClosed) {
        _cascadeStreamController.add(payload);
      }
      return;
    }

    // 針對共享單一 DataChannel 且 Flag 為 0x00 的相容回退分流
    bool isCascadePayload = false;
    try {
      final text = utf8.decode(payload);
      final json = jsonDecode(text);
      if (json is Map) {
        if (json.containsKey('thinking') ||
            json.containsKey('trajectory_step') ||
            json.containsKey('step') ||
            json.containsKey('interaction') ||
            json.containsKey('cascadeId') ||
            json.containsKey('is_final') ||
            json.containsKey('is_thinking')) {
          isCascadePayload = true;
        }
      }
    } catch (_) {}

    if (isCascadePayload) {
      if (!_cascadeStreamController.isClosed) {
        _cascadeStreamController.add(payload);
      }
    } else {
      if (_terminalStreamController.hasListener && !_terminalStreamController.isClosed) {
        _terminalStreamController.add(payload);
      }
      if (!_defaultStreamController.isClosed) {
        _defaultStreamController.add(payload);
      }
    }
  }

  /// 簽署 Channel Binding Nonce 並回傳至桌面端
  Future<void> _respondToChannelBindingChallenge(String nonce) async {
    if (_cryptoService == null || _dataChannel == null) return;

    final signatureBase64 = _cryptoService!.signBase64(nonce);

    final responsePayload = jsonEncode({
      'type': 'channel_binding_response',
      'signature': signatureBase64,
    });

    final frame = frameMessage(Uint8List.fromList(utf8.encode(responsePayload)));
    _dataChannel!.send(RTCDataChannelMessage.fromBinary(frame));
  }

  /// 信令輪詢（含 30 秒超時機制）
  void _startSignalingPoll(String sessionId) {
    _signalingTimer?.cancel();
    int pollElapsedSeconds = 0;

    _signalingTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      pollElapsedSeconds++;
      if (_isChannelAuthenticated || _peerConnection == null) {
        timer.cancel();
        _signalingTimer = null;
        return;
      }

      // 超時機制：若 30 秒未能建立 P2P 連線，關閉輪詢並釋放資源
      if (pollElapsedSeconds >= signalingPollTimeoutSeconds) {
        timer.cancel();
        _signalingTimer = null;
        await disconnect();
        return;
      }

      try {
        final pollUrl =
            Uri.parse('$baseUrl${ApiEndpoints.pollSignalingMessages}');
        final resp = await _httpClient.post(
          pollUrl,
          headers: {
            'Authorization': 'Bearer $googleAccessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'session_id': sessionId,
            'instance_id': targetInstanceUuid,
          }),
        );

        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body) as Map<String, dynamic>;
          final messages = (json['messages'] as List<dynamic>?) ?? [];
          for (final m in messages) {
            final payloadStr = m['payload'] as String?;
            if (payloadStr != null) {
              final payloadJson = jsonDecode(payloadStr) as Map<String, dynamic>;
              if (payloadJson['type'] == 'answer') {
                final sdp = payloadJson['sdp'] as String?;
                if (sdp != null) {
                  final description = RTCSessionDescription(sdp, 'answer');
                  await _peerConnection?.setRemoteDescription(description);
                }
              } else if (payloadJson['candidate'] != null) {
                final candidateMap =
                    payloadJson['candidate'] as Map<String, dynamic>;
                final candidate = RTCIceCandidate(
                  candidateMap['candidate'] as String?,
                  candidateMap['sdpMid'] as String?,
                  candidateMap['sdpMLineIndex'] as int?,
                );
                await _peerConnection?.addCandidate(candidate);
              }
            }
          }
        }
      } catch (_) {
        // 輪詢錯誤
      }
    });
  }

  /// 5-byte 分幀封包組裝 (支援 flag 頻道多工標記)
  static Uint8List frameMessage(Uint8List payload, {int flag = 0x00}) {
    final frame = Uint8List(5 + payload.length);
    frame[0] = flag & 0xFF;
    final len = payload.length;
    frame[1] = (len >> 24) & 0xFF;
    frame[2] = (len >> 16) & 0xFF;
    frame[3] = (len >> 8) & 0xFF;
    frame[4] = len & 0xFF;
    frame.setRange(5, 5 + len, payload);
    return frame;
  }

  @override
  Future<Uint8List> callUnary(String rpcPath, Uint8List payload) async {
    if (!isConnected || _dataChannel == null) {
      throw Exception('WebRTC DataChannel is not connected or authenticated');
    }

    final reqId = _requestIdCounter++;
    final completer = Completer<Uint8List>();
    _pendingRequests[reqId] = completer;

    final frame = frameMessage(payload, flag: 0x00);
    _dataChannel!.send(RTCDataChannelMessage.fromBinary(frame));

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _pendingRequests.remove(reqId);
        throw TimeoutException('P2P DataChannel RPC timeout: $rpcPath');
      },
    );
  }

  @override
  Stream<Uint8List> callStream(String rpcPath, Uint8List payload) {
    if (!isConnected) {
      throw Exception('WebRTC DataChannel is not connected or authenticated');
    }

    int flag = 0x00;
    RTCDataChannel? targetDc = _dataChannel;

    if (rpcPath == ApiEndpoints.streamCascadeReactiveUpdates) {
      flag = 0x01;
      targetDc = _cascadeDataChannel ?? _dataChannel;
    } else if (rpcPath == ApiEndpoints.streamTerminalOutput) {
      flag = 0x02;
      targetDc = _terminalDataChannel ?? _dataChannel;
    }

    final frame = frameMessage(payload, flag: flag);
    if (targetDc != null && targetDc.state == RTCDataChannelState.RTCDataChannelOpen) {
      targetDc.send(RTCDataChannelMessage.fromBinary(frame));
    } else if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage.fromBinary(frame));
    }

    if (rpcPath == ApiEndpoints.streamCascadeReactiveUpdates) {
      return _cascadeStreamController.stream;
    } else if (rpcPath == ApiEndpoints.streamTerminalOutput) {
      return _terminalStreamController.stream;
    }

    return _defaultStreamController.stream;
  }

  @override
  Future<void> disconnect() async {
    _isChannelAuthenticated = false;
    _signalingTimer?.cancel();
    _signalingTimer = null;
    await _dataChannel?.close();
    await _cascadeDataChannel?.close();
    await _terminalDataChannel?.close();
    await _peerConnection?.close();
    _peerConnection = null;
    _dataChannel = null;
    _cascadeDataChannel = null;
    _terminalDataChannel = null;
    _proxyAccumulator.clear();
    _cascadeAccumulator.clear();
    _terminalAccumulator.clear();
  }

  void dispose() {
    disconnect();
    if (!_latencyController.isClosed) _latencyController.close();
    if (!_cascadeStreamController.isClosed) _cascadeStreamController.close();
    if (!_terminalStreamController.isClosed) _terminalStreamController.close();
    if (!_defaultStreamController.isClosed) _defaultStreamController.close();
    _httpClient.close();
  }
}
