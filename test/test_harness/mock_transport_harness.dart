import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:antigravity_remote/core/network/cloud_relay_client.dart';
import 'package:antigravity_remote/core/network/dual_transport_manager.dart';
import 'package:antigravity_remote/core/network/endpoints.dart';
import 'package:antigravity_remote/core/network/webrtc_mesh_client.dart';

class RecordedUnaryCall {
  final String rpcPath;
  final Uint8List payload;

  RecordedUnaryCall({required this.rpcPath, required this.payload});

  String get payloadText => utf8.decode(payload);
  Map<String, dynamic> get payloadJson => jsonDecode(payloadText) as Map<String, dynamic>;
}

class RecordedStreamCall {
  final String rpcPath;
  final Uint8List payload;

  RecordedStreamCall({required this.rpcPath, required this.payload});
}

/// 可控的 Mock 傳輸測試馬具 (Test Harness)
/// 允許直接模擬 5-byte 分幀二進位串流、SCTP 分片、多工分流與狀態反饋
class MockTransportHarness extends DualTransportManager {
  final StreamController<Uint8List> cascadeStreamController =
      StreamController<Uint8List>.broadcast();
  final StreamController<Uint8List> terminalStreamController =
      StreamController<Uint8List>.broadcast();

  final List<RecordedUnaryCall> unaryCalls = [];
  final List<RecordedStreamCall> streamCalls = [];

  Uint8List? unaryResponsePayload;
  Exception? unaryError;

  MockTransportHarness()
      : super(
          relayClient: CloudRelayClient(
            baseUrl: 'https://mock.googleapis.com',
            googleAccessToken: 'mock-token',
            targetInstanceUuid: 'mock-uuid',
          ),
        );

  @override
  Future<void> connectAll() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {
    if (!cascadeStreamController.isClosed) await cascadeStreamController.close();
    if (!terminalStreamController.isClosed) await terminalStreamController.close();
  }

  @override
  Future<Uint8List> callUnary(String rpcPath, Uint8List payload, {bool? isIdempotent}) async {
    unaryCalls.add(RecordedUnaryCall(rpcPath: rpcPath, payload: payload));
    if (unaryError != null) throw unaryError!;
    return unaryResponsePayload ?? Uint8List.fromList(utf8.encode('{"status":"OK"}'));
  }

  @override
  Stream<Uint8List> callStream(String rpcPath, Uint8List payload) {
    streamCalls.add(RecordedStreamCall(rpcPath: rpcPath, payload: payload));
    if (rpcPath == ApiEndpoints.streamCascadeReactiveUpdates) {
      return cascadeStreamController.stream;
    } else if (rpcPath == ApiEndpoints.streamTerminalOutput) {
      return terminalStreamController.stream;
    }
    return const Stream.empty();
  }

  /// 發送 5-byte 分幀二進位封包至 Cascade 串流
  void emitFramedCascadePayload(Uint8List payload, {int flag = 0x01}) {
    final frame = WebRtcMeshClient.frameMessage(payload, flag: flag);
    cascadeStreamController.add(frame);
  }

  /// 發送 JSON 至 Cascade 串流（自動打包 5-byte 分幀標頭）
  void emitFramedCascadeJson(Map<String, dynamic> json, {int flag = 0x01}) {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));
    emitFramedCascadePayload(bytes, flag: flag);
  }

  /// 發送終端文字輸出至 Terminal 串流
  void emitTerminalText(String text) {
    terminalStreamController.add(Uint8List.fromList(utf8.encode(text)));
  }

  /// 發送串流錯誤
  void emitCascadeError(Object error) {
    cascadeStreamController.addError(error);
  }
}
