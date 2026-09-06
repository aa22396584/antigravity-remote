import 'dart:typed_data';
import 'transport_interface.dart';
import 'webrtc_mesh_client.dart';

/// 有界分幀解碼器 (Issue #11)
/// 嚴格驗證長度、旗標與邊界，杜絕將錯誤/二進位內容降級為可讀字元
class FrameDecoder {
  static const int maxFrameLength = 32 * 1024 * 1024; // 32MB

  /// 解碼單一 5-byte 前綴封包 [1B flag] [4B length] [payload]
  static FramePacket decodeSingleFrame(Uint8List bytes) {
    if (bytes.length < 5) {
      throw const ProtocolException('Frame too short: header requires 5 bytes');
    }

    final flag = bytes[0];
    final length = (bytes[1] << 24) |
        (bytes[2] << 16) |
        (bytes[3] << 8) |
        bytes[4];

    if (length < 0 || length > maxFrameLength) {
      throw ProtocolException('Invalid frame length: $length (max: $maxFrameLength)');
    }

    if (bytes.length < 5 + length) {
      throw ProtocolException(
        'Frame truncated: expected ${5 + length} bytes, got ${bytes.length}',
      );
    }

    final payload = Uint8List.fromList(bytes.sublist(5, 5 + length));
    return FramePacket(flag: flag, payload: payload);
  }
}
