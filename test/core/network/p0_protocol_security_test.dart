import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/core/models/instance_info.dart';
import 'package:antigravity_remote/core/network/cloud_relay_client.dart';
import 'package:antigravity_remote/core/network/dual_transport_manager.dart';
import 'package:antigravity_remote/core/network/endpoints.dart';
import 'package:antigravity_remote/core/network/webrtc_mesh_client.dart';

class FakeRelayForP0Test extends CloudRelayClient {
  int callCount = 0;
  String? lastRpcPath;
  Uint8List? lastPayload;

  FakeRelayForP0Test()
      : super(
          baseUrl: 'https://mock.googleapis.com',
          googleAccessToken: 'mock-token',
          targetInstanceUuid: 'mock-uuid',
        );

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<Uint8List> callUnary(String rpcPath, Uint8List payload) async {
    callCount++;
    lastRpcPath = rpcPath;
    lastPayload = payload;
    return Uint8List.fromList(utf8.encode('{"status":"RELAY_OK"}'));
  }
}

class FakeMeshForP0Test extends WebRtcMeshClient {
  bool isP2pOpen = true;
  bool shouldThrowOnCall = false;
  Exception? errorToThrow;
  int meshCallCount = 0;

  FakeMeshForP0Test()
      : super(
          baseUrl: 'https://mock.googleapis.com',
          googleAccessToken: 'mock-token',
          targetInstanceUuid: 'mock-uuid',
        );

  @override
  bool get isConnected => isP2pOpen;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {
    isP2pOpen = false;
  }

  @override
  Future<Uint8List> callUnary(String rpcPath, Uint8List payload) async {
    meshCallCount++;
    if (shouldThrowOnCall) {
      throw errorToThrow ?? TimeoutException('P2P DataChannel timeout on $rpcPath');
    }
    return Uint8List.fromList(utf8.encode('{"status":"P2P_OK"}'));
  }
}

void main() {
  group('P0 #10: 認證狀態過早放行與未認證封包阻絕測試 (Authentication Gating Tests)', () {
    test('drops all unauthenticated business frames prior to Channel Binding ACK', () async {
      final client = WebRtcMeshClient(
        baseUrl: 'https://mock.googleapis.com',
        googleAccessToken: 'mock-token',
        targetInstanceUuid: 'mock-uuid',
      );
      addTearDown(client.dispose);

      expect(client.isChannelAuthenticatedForTesting, isFalse);

      final cascadeChunks = <Uint8List>[];
      final terminalChunks = <Uint8List>[];
      final cascadeSub = client.cascadeStreamForTesting.listen(cascadeChunks.add);
      final terminalSub = client.terminalStreamForTesting.listen(terminalChunks.add);
      addTearDown(cascadeSub.cancel);
      addTearDown(terminalSub.cancel);

      // 1. 嘗試注入未認證的 Cascade 串流封包 (flag 0x01)
      final fakeCascadeFrame = FramePacket(
        flag: 0x01,
        payload: Uint8List.fromList(utf8.encode('{"thinking":"injected unauthenticated prompt"}')),
      );
      await client.routeFrameForTesting(fakeCascadeFrame);

      // 2. 嘗試注入未認證的 Terminal 終端封包 (flag 0x02)
      final fakeTerminalFrame = FramePacket(
        flag: 0x02,
        payload: Uint8List.fromList(utf8.encode('rm -rf / # unauthenticated terminal exploit\n')),
      );
      await client.routeFrameForTesting(fakeTerminalFrame);

      // 3. 嘗試注入未認證的 Unary RPC 偽造回覆 (flag 0x00)
      final fakeRpcFrame = FramePacket(
        flag: 0x00,
        payload: Uint8List.fromList(utf8.encode('{"request_id":1,"payload":"pwned"}')),
      );
      await client.routeFrameForTesting(fakeRpcFrame);

      await Future.delayed(const Duration(milliseconds: 20));

      // 斷言：在未完成 Channel Binding 握手認證前，所有業務封包必須被 100% 阻絕，不得送入業務層
      expect(cascadeChunks, isEmpty, reason: '未認證的 Cascade 封包不應被放行');
      expect(terminalChunks, isEmpty, reason: '未認證的 Terminal 封包不應被放行');
      expect(client.isChannelAuthenticatedForTesting, isFalse);
    });

    test('transitions to authenticated ONLY after receiving Channel Binding ACK', () async {
      final client = WebRtcMeshClient(
        baseUrl: 'https://mock.googleapis.com',
        googleAccessToken: 'mock-token',
        targetInstanceUuid: 'mock-uuid',
      );
      addTearDown(client.dispose);

      final statusUpdates = <bool>[];
      final sub = client.connectionStatusStream.listen(statusUpdates.add);
      addTearDown(sub.cancel);

      // 1. 桌面端發送 Challenge Nonce (32-byte 隨機數)
      final challengeFrame = FramePacket(
        flag: 0x00,
        payload: Uint8List.fromList(utf8.encode(jsonEncode({
          'challenge_nonce': 'dGVzdC1ub25jZS0zMi1ieXRlcy1yYW5kb20=',
        }))),
      );
      await client.routeFrameForTesting(challengeFrame);

      // 斷言：送出簽名後，仍不得直接標記為已認證 (防止 P0 #10 過早放行)
      expect(client.isChannelAuthenticatedForTesting, isFalse);
      expect(statusUpdates, isEmpty);

      // 2. 桌面端驗簽完成，回傳 Channel Binding ACK
      final ackFrame = FramePacket(
        flag: 0x00,
        payload: Uint8List.fromList(utf8.encode(jsonEncode({
          'type': 'channel_binding_ack',
          'status': 'OK',
        }))),
      );
      await client.routeFrameForTesting(ackFrame);

      // 斷言：收到 ACK 後方正式放行認證狀態
      expect(client.isChannelAuthenticatedForTesting, isTrue);
      expect(statusUpdates, contains(true));

      // 3. 認證成功後，業務封包方可正常傳遞
      final cascadeChunks = <Uint8List>[];
      final cSub = client.cascadeStreamForTesting.listen(cascadeChunks.add);
      addTearDown(cSub.cancel);

      final legitCascadeFrame = FramePacket(
        flag: 0x01,
        payload: Uint8List.fromList(utf8.encode('{"thinking":"authenticated thinking"}')),
      );
      await client.routeFrameForTesting(legitCascadeFrame);

      await Future.delayed(const Duration(milliseconds: 10));
      expect(cascadeChunks, isNotEmpty);
      expect(utf8.decode(cascadeChunks.first), contains('authenticated thinking'));
    });
  });

  group('P0 #2: Request ID 配對、防 FIFO 盲配與串流隔離測試', () {
    test('correctly matches out-of-order unary RPC responses by request_id without FIFO mismatch', () async {
      final client = WebRtcMeshClient(
        baseUrl: 'https://mock.googleapis.com',
        googleAccessToken: 'mock-token',
        targetInstanceUuid: 'mock-uuid',
      );
      addTearDown(client.dispose);

      // 模擬連線已通過認證
      client.setChannelAuthenticatedForTesting(true);

      // 註冊兩個並行非同步請求
      final completerReq1 = Completer<Uint8List>();
      final completerReq2 = Completer<Uint8List>();
      client.pendingRequestsForTesting[101] = completerReq1;
      client.pendingRequestsForTesting[102] = completerReq2;

      // 模擬亂序回傳：請求 102 的回應先到達，請求 101 的回應後到達
      final respFor102 = FramePacket(
        flag: 0x00,
        payload: Uint8List.fromList(utf8.encode(jsonEncode({
          'request_id': 102,
          'payload': base64Encode(utf8.encode('Response For Request 102')),
        }))),
      );

      final respFor101 = FramePacket(
        flag: 0x00,
        payload: Uint8List.fromList(utf8.encode(jsonEncode({
          'request_id': 101,
          'payload': base64Encode(utf8.encode('Response For Request 101')),
        }))),
      );

      // 遞送 102 回覆
      await client.routeFrameForTesting(respFor102);
      expect(completerReq2.isCompleted, isTrue, reason: 'Request 102 應已依 request_id 精確完成');
      expect(completerReq1.isCompleted, isFalse, reason: 'Request 101 絕不可被 FIFO 盲配搶先完成');

      final res2 = await completerReq2.future;
      expect(utf8.decode(res2), 'Response For Request 102');

      // 遞送 101 回覆
      await client.routeFrameForTesting(respFor101);
      expect(completerReq1.isCompleted, isTrue);

      final res1 = await completerReq1.future;
      expect(utf8.decode(res1), 'Response For Request 101');
    });

    test('drops response frames with missing or unmatched request_id without popping FIFO queue', () async {
      final client = WebRtcMeshClient(
        baseUrl: 'https://mock.googleapis.com',
        googleAccessToken: 'mock-token',
        targetInstanceUuid: 'mock-uuid',
      );
      addTearDown(client.dispose);

      client.setChannelAuthenticatedForTesting(true);

      final completer = Completer<Uint8List>();
      completer.future.ignore();
      client.pendingRequestsForTesting[200] = completer;

      // 發送不帶 request_id 的封包
      final noIdFrame = FramePacket(
        flag: 0x00,
        payload: Uint8List.fromList(utf8.encode('{"payload":"raw response"}')),
      );
      await client.routeFrameForTesting(noIdFrame);

      // 發送錯誤 request_id (999) 的封包
      final wrongIdFrame = FramePacket(
        flag: 0x00,
        payload: Uint8List.fromList(utf8.encode('{"request_id":999,"payload":"other"}')),
      );
      await client.routeFrameForTesting(wrongIdFrame);

      await Future.delayed(const Duration(milliseconds: 10));

      // 斷言：禁止純 FIFO 盲配，等待中的 200 不會被錯誤消耗
      expect(completer.isCompleted, isFalse);
      expect(client.pendingRequestsForTesting.containsKey(200), isTrue);
    });

    test('strictly isolates Terminal and Cascade streams and never leaks RPC frames into Terminal', () async {
      final client = WebRtcMeshClient(
        baseUrl: 'https://mock.googleapis.com',
        googleAccessToken: 'mock-token',
        targetInstanceUuid: 'mock-uuid',
      );
      addTearDown(client.dispose);

      client.setChannelAuthenticatedForTesting(true);

      final cascadeEvents = <Uint8List>[];
      final terminalEvents = <Uint8List>[];
      final cSub = client.cascadeStreamForTesting.listen(cascadeEvents.add);
      final tSub = client.terminalStreamForTesting.listen(terminalEvents.add);
      addTearDown(cSub.cancel);
      addTearDown(tSub.cancel);

      // 1. 發送 Flag 0x01 (Cascade)
      final cascadeFrame = FramePacket(
        flag: 0x01,
        payload: Uint8List.fromList(utf8.encode('cascade event chunk')),
      );
      await client.routeFrameForTesting(cascadeFrame);

      // 2. 發送 Flag 0x02 (Terminal)
      final terminalFrame = FramePacket(
        flag: 0x02,
        payload: Uint8List.fromList(utf8.encode('terminal output chunk\n')),
      );
      await client.routeFrameForTesting(terminalFrame);

      // 3. 發送 Flag 0x00 (Unary RPC / 未知控制封包)
      final rpcFrame = FramePacket(
        flag: 0x00,
        payload: Uint8List.fromList(utf8.encode('{"status":"unknown"}')),
      );
      await client.routeFrameForTesting(rpcFrame);

      await Future.delayed(const Duration(milliseconds: 15));

      // 斷言：Cascade 串流僅接收到 0x01
      expect(cascadeEvents.length, 1);
      expect(utf8.decode(cascadeEvents.first), 'cascade event chunk');

      // 斷言：Terminal 串流僅接收到 0x02，且未知的 0x00 封包絕不外洩污染終端
      expect(terminalEvents.length, 1);
      expect(utf8.decode(terminalEvents.first), 'terminal output chunk\n');
    });
  });

  group('P0 #3: 寫入重複執行防禦測試 (Duplicate Write on Relay Retry Tests)', () {
    test('blocks relay retry and throws DuplicateExecutionPreventedException when in-flight non-idempotent RPC fails', () async {
      final fakeRelay = FakeRelayForP0Test();
      final fakeMesh = FakeMeshForP0Test();
      fakeMesh.isP2pOpen = true;
      fakeMesh.shouldThrowOnCall = true; // 模擬 P2P 已在途中 (in-flight) 但連線逾時/遺失回覆
      fakeMesh.errorToThrow = TimeoutException('P2P 網路超時');

      final manager = DualTransportManager(
        relayClient: fakeRelay,
        meshClient: fakeMesh,
      );
      addTearDown(manager.dispose);

      // 測試三種高危險非冪等 RPC 請求
      final nonIdempotentRpcs = [
        ApiEndpoints.sendUserCascadeMessage,
        ApiEndpoints.sendTerminalInput,
        ApiEndpoints.handleCascadeUserInteraction,
      ];

      for (final rpc in nonIdempotentRpcs) {
        fakeRelay.callCount = 0;
        fakeMesh.meshCallCount = 0;

        expect(
          () => manager.callUnary(rpc, Uint8List.fromList(utf8.encode('{"cmd":"test"}'))),
          throwsA(isA<DuplicateExecutionPreventedException>()),
          reason: '$rpc 為非冪等操作，在途失敗時必須阻止自動重送',
        );

        // 核心安全斷言：Relay Client 呼叫計數必須維持 0！絕對不可自動重送以防重複執行
        expect(fakeRelay.callCount, 0, reason: '$rpc 絕不可透過 Relay 重複發送');
        expect(fakeMesh.meshCallCount, 1);
        expect(manager.currentTransport, TransportType.relay, reason: '應已安全降級為中繼模式等待手動重試');
      }
    });

    test('allows safe relay fallback for idempotent query RPCs when P2P fails in-flight', () async {
      final fakeRelay = FakeRelayForP0Test();
      final fakeMesh = FakeMeshForP0Test();
      fakeMesh.isP2pOpen = true;
      fakeMesh.shouldThrowOnCall = true;
      fakeMesh.errorToThrow = TimeoutException('P2P 暫態中斷');

      final manager = DualTransportManager(
        relayClient: fakeRelay,
        meshClient: fakeMesh,
      );
      addTearDown(manager.dispose);

      // 冪等性查詢 RPC：可安全自動切換至 Relay 重試
      final res = await manager.callUnary(
        ApiEndpoints.listInstances,
        Uint8List.fromList(utf8.encode('{}')),
      );

      expect(utf8.decode(res), '{"status":"RELAY_OK"}');
      expect(fakeMesh.meshCallCount, 1);
      expect(fakeRelay.callCount, 1, reason: '冪等性查詢允許安全 Fallback Relay');
      expect(manager.currentTransport, TransportType.relay);
    });

    test('routes directly to relay when P2P was offline from start (not a retry)', () async {
      final fakeRelay = FakeRelayForP0Test();
      final fakeMesh = FakeMeshForP0Test();
      fakeMesh.isP2pOpen = false; // P2P 從未連通

      final manager = DualTransportManager(
        relayClient: fakeRelay,
        meshClient: fakeMesh,
      );
      addTearDown(manager.dispose);

      final res = await manager.callUnary(
        ApiEndpoints.sendTerminalInput,
        Uint8List.fromList(utf8.encode('ls -la\n')),
      );

      expect(utf8.decode(res), '{"status":"RELAY_OK"}');
      expect(fakeMesh.meshCallCount, 0, reason: 'P2P 未連線，直接由 Relay 承接首發');
      expect(fakeRelay.callCount, 1);
    });
  });
}
