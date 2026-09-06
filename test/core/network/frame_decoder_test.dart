import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/core/network/frame_decoder.dart';
import 'package:antigravity_remote/core/network/transport_interface.dart';

void main() {
  group('FrameDecoder Tests (Issue #11)', () {
    test('decodes valid 5-byte framed packet', () {
      final payload = utf8.encode('{"status":"ok"}');
      final len = payload.length;
      final bytes = Uint8List.fromList([
        0x01, // flag
        (len >> 24) & 0xFF,
        (len >> 16) & 0xFF,
        (len >> 8) & 0xFF,
        len & 0xFF,
        ...payload,
      ]);

      final frame = FrameDecoder.decodeSingleFrame(bytes);
      expect(frame.flag, 0x01);
      expect(utf8.decode(frame.payload), '{"status":"ok"}');
    });

    test('throws ProtocolException on truncated header (<5 bytes)', () {
      final truncated = Uint8List.fromList([0x00, 0x00, 0x01]);
      expect(
        () => FrameDecoder.decodeSingleFrame(truncated),
        throwsA(isA<ProtocolException>()),
      );
    });

    test('throws ProtocolException on truncated payload', () {
      final truncatedPayload = Uint8List.fromList([
        0x00,
        0x00, 0x00, 0x00, 0x10, // length = 16
        0x01, 0x02, // only 2 bytes
      ]);
      expect(
        () => FrameDecoder.decodeSingleFrame(truncatedPayload),
        throwsA(isA<ProtocolException>()),
      );
    });

    test('throws ProtocolException on invalid negative or excessive length', () {
      final invalidLen = Uint8List.fromList([
        0x00,
        0x80, 0x00, 0x00, 0x00, // Negative or overflow length
        0x01,
      ]);
      expect(
        () => FrameDecoder.decodeSingleFrame(invalidLen),
        throwsA(isA<ProtocolException>()),
      );
    });
  });
}
