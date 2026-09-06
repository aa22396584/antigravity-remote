import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:antigravity_remote/core/network/cloud_relay_client.dart';

void main() {
  group('CloudRelayClient Tests', () {
    test(
      'callUnary encodes ProxyCommandRequest and decodes base64 payload response',
      () async {
        final mockHttpClient = MockClient((request) async {
          expect(request.url.path, contains('ProxyCommand'));
          expect(request.headers['Authorization'], 'Bearer mock-google-token');
          expect(request.headers['Content-Type'], 'application/json');

          final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
          expect(reqBody['target_instance_uuid'], 'test-uuid-123');
          expect(
            reqBody['rpc_path'],
            '/exa.LanguageServerService/SendUserCascadeMessage',
          );

          // Check base64 input
          final inputBytes = base64Decode(reqBody['payload'] as String);
          expect(utf8.decode(inputBytes), 'Ping Antigravity');

          final respPayload = base64Encode(
            utf8.encode('Pong from Antigravity'),
          );
          return http.Response(
            jsonEncode({'payload': respPayload, 'headers': []}),
            200,
          );
        });

        final client = CloudRelayClient(
          baseUrl: 'https://cloudcode-pa.googleapis.com',
          googleAccessToken: 'mock-google-token',
          targetInstanceUuid: 'test-uuid-123',
          httpClient: mockHttpClient,
        );

        final result = await client.callUnary(
          '/exa.LanguageServerService/SendUserCascadeMessage',
          Uint8List.fromList(utf8.encode('Ping Antigravity')),
        );

        expect(utf8.decode(result), 'Pong from Antigravity');
      },
    );

    test('ping measures network round-trip time and updates latency', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(jsonEncode({'instances': []}), 200);
      });

      final client = CloudRelayClient(
        baseUrl: 'https://cloudcode-pa.googleapis.com',
        googleAccessToken: 'mock-token',
        targetInstanceUuid: 'test-uuid',
        httpClient: mockHttpClient,
      );

      await client.connect();
      final latency = await client.ping();

      expect(latency, isNotNull);
      expect(client.currentLatencyMs, isNotNull);
      client.dispose();
    });
  });
}
