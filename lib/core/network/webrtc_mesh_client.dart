import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import '../models/instance_info.dart';
import 'ecdsa_p256_service.dart';
import 'endpoints.dart';
import 'transport_interface.dart';

class WebRtcMeshClient implements TransportClient {
  final String baseUrl;
  final String googleAccessToken;
  final String targetInstanceUuid;
  final String clientInstanceId;
  final http.Client _httpClient;

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  EcdsaP256Service? _cryptoService;
  Timer? _signalingTimer;

  bool _isChannelAuthenticated = false;
  int? _lastLatencyMs;
  final _latencyController = StreamController<int>.broadcast();
  final _streamController = StreamController<Uint8List>.broadcast();
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
      _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen &&
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

      // 4. 建立 DataChannel
      final dcInit = RTCDataChannelInit()..ordered = true;
      _dataChannel = await _peerConnection!.createDataChannel(
        'proxy-channel',
        dcInit,
      );

      _setupDataChannelListeners();

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

      // 6. 輪詢桌面端回傳之 SDP Answer
      _startSignalingPoll(sessionId);
    } catch (e) {
      _isChannelAuthenticated = false;
      rethrow;
    }
  }

  void _setupDataChannelListeners() {
    if (_dataChannel == null) return;

    _dataChannel!.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        // DataChannel 已連通，等待 Channel Binding 挑戰
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _isChannelAuthenticated = false;
      }
    };

    _dataChannel!.onMessage = (RTCDataChannelMessage msg) async {
      if (msg.isBinary) {
        await _handleIncomingBinaryMessage(msg.binary);
      }
    };
  }

  /// 處理 5-byte 分幀與 Channel Binding 簽名驗證
  Future<void> _handleIncomingBinaryMessage(Uint8List rawBytes) async {
    if (rawBytes.length < 5) return;

    // 前綴格式：[1 byte Flag: 0x00] [4 bytes BigEndian Length] [Payload]
    final length = (rawBytes[1] << 24) |
        (rawBytes[2] << 16) |
        (rawBytes[3] << 8) |
        rawBytes[4];

    if (rawBytes.length < 5 + length) return;
    final payload = rawBytes.sublist(5, 5 + length);

    // 檢查是否為 Channel Binding Challenge
    if (!_isChannelAuthenticated) {
      try {
        final challengeJson = jsonDecode(utf8.decode(payload));
        if (challengeJson is Map && challengeJson['challenge_nonce'] != null) {
          await _respondToChannelBindingChallenge(
            challengeJson['challenge_nonce'] as String,
          );
          _isChannelAuthenticated = true;
          _lastLatencyMs = 12; // Initial P2P estimate
          _latencyController.add(_lastLatencyMs!);
          return;
        }
      } catch (_) {
        // Non-JSON, proceed to standard payload handling
      }
    }

    _streamController.add(payload);

    // If matching a pending unary request
    if (_pendingRequests.isNotEmpty) {
      final firstKey = _pendingRequests.keys.first;
      final completer = _pendingRequests.remove(firstKey);
      completer?.complete(payload);
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

  void _startSignalingPoll(String sessionId) {
    _signalingTimer?.cancel();
    _signalingTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (_isChannelAuthenticated || _peerConnection == null) {
        timer.cancel();
        _signalingTimer = null;
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
        // Poll error
      }
    });
  }

  /// 5-byte 分幀封包組裝
  static Uint8List frameMessage(Uint8List payload) {
    final frame = Uint8List(5 + payload.length);
    frame[0] = 0x00; // uncompressed
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

    final frame = frameMessage(payload);
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
    if (!isConnected || _dataChannel == null) {
      throw Exception('WebRTC DataChannel is not connected or authenticated');
    }

    final frame = frameMessage(payload);
    _dataChannel!.send(RTCDataChannelMessage.fromBinary(frame));

    return _streamController.stream;
  }

  @override
  Future<void> disconnect() async {
    _isChannelAuthenticated = false;
    _signalingTimer?.cancel();
    _signalingTimer = null;
    await _dataChannel?.close();
    await _peerConnection?.close();
    _peerConnection = null;
    _dataChannel = null;
  }

  void dispose() {
    disconnect();
    _latencyController.close();
    _streamController.close();
    _httpClient.close();
  }
}
