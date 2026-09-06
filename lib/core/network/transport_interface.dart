import 'dart:typed_data';
import '../models/instance_info.dart';

abstract class TransportClient {
  TransportType get transportType;
  bool get isConnected;
  Stream<int> get latencyStream;
  int? get currentLatencyMs;

  Future<void> connect();
  Future<void> disconnect();

  Future<Uint8List> callUnary(String rpcPath, Uint8List payload);
  Stream<Uint8List> callStream(String rpcPath, Uint8List payload);
}

/// RPC 執行失敗異常（對端明確回傳錯誤）
class RpcException implements Exception {
  final String message;
  final int? statusCode;
  final Object? details;

  const RpcException(this.message, {this.statusCode, this.details});

  @override
  String toString() =>
      'RpcException: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

/// 封包在發送前就失敗（根本未送出到網路線路，例如未連線、DataChannel 關閉或 send 拋錯）
class PreFlightException implements Exception {
  final String message;
  final Object? cause;

  const PreFlightException(this.message, {this.cause});

  @override
  String toString() =>
      'PreFlightException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// 封包已成功交付底層 DataChannel 送出（In-flight / Commit），但後續等待回覆時逾時或斷線
class InFlightRpcException implements Exception {
  final String rpcPath;
  final Object cause;

  const InFlightRpcException({required this.rpcPath, required this.cause});

  @override
  String toString() => 'InFlightRpcException on $rpcPath: $cause';
}

/// 協議解析失敗異常（收到畸形或無法識別的訊框，禁止將二進位/錯誤字元當作正常文字處理）
class ProtocolException implements Exception {
  final String message;
  final Object? cause;

  const ProtocolException(this.message, {this.cause});

  @override
  String toString() =>
      'ProtocolException: $message${cause != null ? ' (cause: $cause)' : ''}';
}
