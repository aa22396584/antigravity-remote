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
