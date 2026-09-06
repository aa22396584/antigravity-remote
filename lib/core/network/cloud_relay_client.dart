import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/instance_info.dart';
import 'endpoints.dart';
import 'transport_interface.dart';

class CloudRelayClient implements TransportClient {
  final String baseUrl;
  final String googleAccessToken;
  final String targetInstanceUuid;
  final http.Client _httpClient;

  bool _isConnected = false;
  int? _lastLatencyMs;
  final _latencyController = StreamController<int>.broadcast();
  Timer? _heartbeatTimer;

  CloudRelayClient({
    required this.baseUrl,
    required this.googleAccessToken,
    required this.targetInstanceUuid,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  TransportType get transportType => TransportType.relay;

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<int> get latencyStream => _latencyController.stream;

  @override
  int? get currentLatencyMs => _lastLatencyMs;

  @override
  Future<void> connect() async {
    _isConnected = true;
    _startPingTimer();
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _startPingTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!_isConnected) return;
      await ping();
    });
  }

  Future<int?> ping() async {
    final sw = Stopwatch()..start();
    try {
      final url = Uri.parse('$baseUrl${ApiEndpoints.listInstances}');
      final resp = await _httpClient.post(
        url,
        headers: {
          'Authorization': 'Bearer $googleAccessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'project': 'jetski-remote'}),
      ).timeout(const Duration(seconds: 5));

      sw.stop();
      if (resp.statusCode == 200 || resp.statusCode == 401) {
        // Even 401 proves network reachability and latency
        _lastLatencyMs = sw.elapsedMilliseconds;
        _latencyController.add(_lastLatencyMs!);
        return _lastLatencyMs;
      }
    } catch (_) {
      // Network unreachable or timeout
    }
    return null;
  }

  @override
  Future<Uint8List> callUnary(String rpcPath, Uint8List payload) async {
    final sw = Stopwatch()..start();
    final url = Uri.parse('$baseUrl${ApiEndpoints.proxyCommand}');

    final reqBody = {
      'target_instance_uuid': targetInstanceUuid,
      'rpc_path': rpcPath,
      'payload': base64Encode(payload),
      'headers': [
        {'key': 'x-is-streaming', 'value': 'false'},
        {'key': 'content-type', 'value': 'application/proto'},
      ],
    };

    final resp = await _httpClient.post(
      url,
      headers: {
        'Authorization': 'Bearer $googleAccessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(reqBody),
    ).timeout(const Duration(seconds: 30));

    sw.stop();
    _lastLatencyMs = sw.elapsedMilliseconds;
    _latencyController.add(_lastLatencyMs!);

    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final base64Payload = json['payload'] as String?;
      if (base64Payload != null) {
        return base64Decode(base64Payload);
      }
      final payloadText = json['payload_text'] as String?;
      if (payloadText != null) {
        return Uint8List.fromList(utf8.encode(payloadText));
      }
      return Uint8List(0);
    } else {
      throw Exception(
        'Cloud Relay ProxyCommand error: HTTP ${resp.statusCode} - ${resp.body}',
      );
    }
  }

  @override
  Stream<Uint8List> callStream(String rpcPath, Uint8List payload) async* {
    final url = Uri.parse('$baseUrl${ApiEndpoints.streamProxyCommand}');

    final request = http.Request('POST', url)
      ..headers.addAll({
        'Authorization': 'Bearer $googleAccessToken',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({
        'target_instance_uuid': targetInstanceUuid,
        'rpc_path': rpcPath,
        'payload': base64Encode(payload),
        'headers': [
          {'key': 'x-is-streaming', 'value': 'true'},
          {'key': 'content-type', 'value': 'application/proto'},
        ],
      });

    final streamedResponse = await _httpClient.send(request);

    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw Exception(
        'StreamProxyCommand failed: HTTP ${streamedResponse.statusCode} - $body',
      );
    }

    // Stream lines or chunks
    var buffer = '';
    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.removeLast(); // keep incomplete tail

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        try {
          final json = jsonDecode(trimmed) as Map<String, dynamic>;
          final base64Payload = json['payload'] as String?;
          if (base64Payload != null) {
            yield base64Decode(base64Payload);
          } else if (json['payload_text'] != null) {
            yield Uint8List.fromList(utf8.encode(json['payload_text'] as String));
          }
        } catch (_) {
          // If raw chunk
          yield Uint8List.fromList(utf8.encode(trimmed));
        }
      }
    }

    if (buffer.trim().isNotEmpty) {
      try {
        final json = jsonDecode(buffer.trim()) as Map<String, dynamic>;
        final base64Payload = json['payload'] as String?;
        if (base64Payload != null) {
          yield base64Decode(base64Payload);
        } else if (json['payload_text'] != null) {
          yield Uint8List.fromList(utf8.encode(json['payload_text'] as String));
        }
      } catch (_) {
        yield Uint8List.fromList(utf8.encode(buffer.trim()));
      }
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _latencyController.close();
    _httpClient.close();
  }
}
