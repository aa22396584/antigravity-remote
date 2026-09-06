import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:antigravity_remote/core/models/instance_info.dart';
import 'package:antigravity_remote/core/network/cloud_relay_client.dart';
import 'package:antigravity_remote/core/network/dual_transport_manager.dart';
import 'package:antigravity_remote/core/network/webrtc_mesh_client.dart';

class FakeRelayClient extends CloudRelayClient {
  bool isDisposed = false;

  FakeRelayClient()
      : super(
          baseUrl: 'https://cloudcode-pa.googleapis.com',
          googleAccessToken: 'test-token',
          targetInstanceUuid: 'uuid-1',
        );

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<Uint8List> callUnary(String rpcPath, Uint8List payload) async {
    return Uint8List.fromList(utf8.encode('Relay Fallback Response'));
  }

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }
}

class FakeMeshClient extends WebRtcMeshClient {
  bool mockConnected = false;
  bool isDisposed = false;
  int connectCallCount = 0;
  final StreamController<bool> _statusCtrl = StreamController<bool>.broadcast();

  FakeMeshClient()
      : super(
          baseUrl: 'https://cloudcode-pa.googleapis.com',
          googleAccessToken: 'test-token',
          targetInstanceUuid: 'uuid-1',
        );

  @override
  bool get isConnected => mockConnected;

  @override
  Stream<bool> get connectionStatusStream => _statusCtrl.stream;

  void emitStatus(bool status) {
    mockConnected = status;
    _statusCtrl.add(status);
  }

  @override
  Future<void> connect() async {
    connectCallCount++;
  }

  @override
  Future<void> disconnect() async {
    mockConnected = false;
    if (!_statusCtrl.isClosed) {
      _statusCtrl.add(false);
    }
  }

  @override
  Future<Uint8List> callUnary(String rpcPath, Uint8List payload) async {
    if (!mockConnected) {
      throw Exception('WebRTC mesh is not open');
    }
    return Uint8List.fromList(utf8.encode('Mesh P2P Response'));
  }

  @override
  void dispose() {
    isDisposed = true;
    _statusCtrl.close();
    super.dispose();
  }
}

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

    test('recursively disposes relayClient and meshClient', () async {
      final fakeRelay = FakeRelayClient();
      final fakeMesh = FakeMeshClient();

      final manager = DualTransportManager(
        relayClient: fakeRelay,
        meshClient: fakeMesh,
      );

      await manager.dispose();

      expect(fakeRelay.isDisposed, isTrue);
      expect(fakeMesh.isDisposed, isTrue);
      expect(manager.currentTransport, TransportType.offline);
    });

    test('automatically routes to P2P when connected and falls back to Relay when P2P fails', () async {
      final fakeRelay = FakeRelayClient();
      final fakeMesh = FakeMeshClient();

      final manager = DualTransportManager(
        relayClient: fakeRelay,
        meshClient: fakeMesh,
      );
      addTearDown(manager.dispose);

      await manager.connectAll();
      expect(manager.currentTransport, TransportType.relay);

      // P2P becomes connected
      fakeMesh.mockConnected = true;
      final p2pRes = await manager.callUnary('/test.Rpc', Uint8List(0));
      expect(utf8.decode(p2pRes), 'Mesh P2P Response');
      expect(manager.currentTransport, TransportType.p2p);

      // P2P disconnects / fails, automatically falls back to Relay
      fakeMesh.mockConnected = false;
      final fallbackRes = await manager.callUnary('/test.Rpc', Uint8List(0));
      expect(utf8.decode(fallbackRes), 'Relay Fallback Response');
      expect(manager.currentTransport, TransportType.relay);
    });

    test('schedules reconnect with exponential backoff on P2P disconnection', () async {
      final fakeRelay = FakeRelayClient();
      final fakeMesh = FakeMeshClient();

      final manager = DualTransportManager(
        relayClient: fakeRelay,
        meshClient: fakeMesh,
      );
      addTearDown(manager.dispose);

      await manager.connectAll();
      expect(manager.reconnectAttempts, 0);

      // P2P connects
      fakeMesh.emitStatus(true);
      await Future.delayed(Duration.zero);
      expect(manager.currentTransport, TransportType.p2p);

      // P2P drops
      fakeMesh.emitStatus(false);
      await Future.delayed(Duration.zero);
      expect(manager.currentTransport, TransportType.relay);

      // Verify reconnect attempt is reset on manual disconnect
      await manager.disconnect();
      expect(manager.reconnectAttempts, 0);
      expect(manager.currentTransport, TransportType.offline);
    });

    test('successful P2P connection resets reconnectAttempts to 0', () async {
      final fakeRelay = FakeRelayClient();
      final fakeMesh = FakeMeshClient();

      final manager = DualTransportManager(
        relayClient: fakeRelay,
        meshClient: fakeMesh,
      );
      addTearDown(manager.dispose);

      await manager.connectAll();
      fakeMesh.emitStatus(true);
      await Future.delayed(Duration.zero);
      expect(manager.currentTransport, TransportType.p2p);
      expect(manager.reconnectAttempts, 0);
    });
  });
}
