import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:antigravity_remote/core/models/instance_info.dart';
import 'package:antigravity_remote/core/network/cloud_relay_client.dart';
import 'package:antigravity_remote/core/network/dual_transport_manager.dart';

void main() {
  group('DualTransportManager Tests', () {
    test('routes through Cloud Relay as default baseline', () async {
      final mockHttpClient = MockClient((request) async {
        final respPayload = base64Encode(utf8.encode('Relay Response'));
        return http.Response(
          jsonEncode({'payload': respPayload, 'headers': []}),
          200,
        );
      });

      final relayClient = CloudRelayClient(
        baseUrl: 'https://cloudcode-pa.googleapis.com',
        googleAccessToken: 'test-token',
        targetInstanceUuid: 'uuid-1',
        httpClient: mockHttpClient,
      );

      final manager = DualTransportManager(relayClient: relayClient);
      await manager.connectAll();

      expect(manager.currentTransport, TransportType.relay);

      final result = await manager.callUnary('/test.Rpc', Uint8List.fromList(utf8.encode('Hello')));
      expect(utf8.decode(result), 'Relay Response');

      await manager.disconnect();
      expect(manager.currentTransport, TransportType.offline);
    });
  });
}
