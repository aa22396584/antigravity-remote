import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/core/network/webrtc_mesh_client.dart';

void main() {
  group('WebRTC DataChannel 5-byte Framing Tests', () {
    test('frameMessage creates correct 5-byte header [0x00, len_b3, len_b2, len_b1, len_b0]', () {
      final payload = Uint8List.fromList(utf8.encode('Hello Antigravity'));
      final frame = WebRtcMeshClient.frameMessage(payload);

      // Total length: 5 bytes header + payload length
      expect(frame.length, 5 + payload.length);

      // Byte 0: compression flag (0x00 = uncompressed)
      expect(frame[0], 0x00);

      // Bytes 1..4: Big-Endian 32-bit length
      final length = (frame[1] << 24) | (frame[2] << 16) | (frame[3] << 8) | frame[4];
      expect(length, payload.length);

      // Bytes 5..end: original payload
      final extractedPayload = frame.sublist(5);
      expect(utf8.decode(extractedPayload), 'Hello Antigravity');
    });

    test('frameMessage handles empty payload', () {
      final payload = Uint8List(0);
      final frame = WebRtcMeshClient.frameMessage(payload);

      expect(frame.length, 5);
      expect(frame[0], 0x00);
      expect(frame[1], 0);
      expect(frame[2], 0);
      expect(frame[3], 0);
      expect(frame[4], 0);
    });

    test('frameMessage handles large payload length encoding', () {
      // 65536 bytes (0x00010000)
      final largePayload = Uint8List(65536);
      largePayload[0] = 0xAA;
      largePayload[65535] = 0xBB;

      final frame = WebRtcMeshClient.frameMessage(largePayload);

      expect(frame.length, 5 + 65536);
      expect(frame[0], 0x00);
      expect(frame[1], 0x00);
      expect(frame[2], 0x01); // 65536 >> 16 & 0xFF
      expect(frame[3], 0x00);
      expect(frame[4], 0x00);

      expect(frame[5], 0xAA);
      expect(frame[5 + 65535], 0xBB);
    });
  });
}
