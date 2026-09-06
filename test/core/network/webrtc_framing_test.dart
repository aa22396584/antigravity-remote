import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/core/network/webrtc_mesh_client.dart';

void main() {
  group('WebRTC DataChannel 5-byte Framing Tests', () {
    test('frameMessage creates correct 5-byte header [flag, len_b3, len_b2, len_b1, len_b0]', () {
      final payload = Uint8List.fromList(utf8.encode('Hello Antigravity'));
      final frame = WebRtcMeshClient.frameMessage(payload, flag: 0x01);

      // Total length: 5 bytes header + payload length
      expect(frame.length, 5 + payload.length);

      // Byte 0: flag (0x01 = cascade)
      expect(frame[0], 0x01);

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
      final largePayload = Uint8List(65536);
      largePayload[0] = 0xAA;
      largePayload[65535] = 0xBB;

      final frame = WebRtcMeshClient.frameMessage(largePayload, flag: 0x02);

      expect(frame.length, 5 + 65536);
      expect(frame[0], 0x02); // Terminal flag
      expect(frame[1], 0x00);
      expect(frame[2], 0x01); // 65536 >> 16 & 0xFF
      expect(frame[3], 0x00);
      expect(frame[4], 0x00);

      expect(frame[5], 0xAA);
      expect(frame[5 + 65535], 0xBB);
    });
  });

  group('FrameAccumulator SCTP Fragmentation & Sticky Packets Tests', () {
    test('handles single complete frame', () {
      final accumulator = FrameAccumulator();
      final payload = Uint8List.fromList(utf8.encode('single frame'));
      final frame = WebRtcMeshClient.frameMessage(payload, flag: 0x01);

      accumulator.push(frame);
      final drained = accumulator.drainFrames();

      expect(drained.length, 1);
      expect(drained.first.flag, 0x01);
      expect(utf8.decode(drained.first.payload), 'single frame');
      expect(accumulator.bufferedBytes, 0);
    });

    test('reconstructs frame fragmented across 3 SCTP chunks', () {
      final accumulator = FrameAccumulator();
      final payload = Uint8List.fromList(utf8.encode('fragmented SCTP message across chunks'));
      final frame = WebRtcMeshClient.frameMessage(payload, flag: 0x02);

      // Fragment 1: First 3 bytes of header
      accumulator.push(frame.sublist(0, 3));
      expect(accumulator.drainFrames(), isEmpty);
      expect(accumulator.bufferedBytes, 3);

      // Fragment 2: Remaining 2 bytes of header + 10 bytes of body
      accumulator.push(frame.sublist(3, 15));
      expect(accumulator.drainFrames(), isEmpty);
      expect(accumulator.bufferedBytes, 15);

      // Fragment 3: Remaining bytes of body
      accumulator.push(frame.sublist(15));
      final drained = accumulator.drainFrames();

      expect(drained.length, 1);
      expect(drained.first.flag, 0x02);
      expect(utf8.decode(drained.first.payload), 'fragmented SCTP message across chunks');
      expect(accumulator.bufferedBytes, 0);
    });

    test('correctly handles sticky packets with multiple concatenated frames', () {
      final accumulator = FrameAccumulator();
      final f1 = WebRtcMeshClient.frameMessage(Uint8List.fromList(utf8.encode('frame-1')), flag: 0x01);
      final f2 = WebRtcMeshClient.frameMessage(Uint8List.fromList(utf8.encode('frame-2-larger-payload')), flag: 0x02);
      final f3 = WebRtcMeshClient.frameMessage(Uint8List.fromList(utf8.encode('frame-3')), flag: 0x00);

      // Combine all three into one sticky network chunk
      final sticky = Uint8List.fromList([...f1, ...f2, ...f3]);
      accumulator.push(sticky);

      final drained = accumulator.drainFrames();
      expect(drained.length, 3);

      expect(drained[0].flag, 0x01);
      expect(utf8.decode(drained[0].payload), 'frame-1');

      expect(drained[1].flag, 0x02);
      expect(utf8.decode(drained[1].payload), 'frame-2-larger-payload');

      expect(drained[2].flag, 0x00);
      expect(utf8.decode(drained[2].payload), 'frame-3');

      expect(accumulator.bufferedBytes, 0);
    });

    test('preserves partial frame in buffer when sticky chunk has incomplete tail', () {
      final accumulator = FrameAccumulator();
      final f1 = WebRtcMeshClient.frameMessage(Uint8List.fromList(utf8.encode('complete-frame')), flag: 0x01);
      final f2 = WebRtcMeshClient.frameMessage(Uint8List.fromList(utf8.encode('tail-frame')), flag: 0x02);

      // Send f1 + only the header of f2
      accumulator.push(Uint8List.fromList([...f1, ...f2.sublist(0, 5)]));

      final firstDrain = accumulator.drainFrames();
      expect(firstDrain.length, 1);
      expect(utf8.decode(firstDrain[0].payload), 'complete-frame');
      expect(accumulator.bufferedBytes, 5); // header of f2 remains

      // Send rest of f2
      accumulator.push(f2.sublist(5));
      final secondDrain = accumulator.drainFrames();
      expect(secondDrain.length, 1);
      expect(utf8.decode(secondDrain[0].payload), 'tail-frame');
      expect(accumulator.bufferedBytes, 0);
    });

    test('clear resets internal buffer', () {
      final accumulator = FrameAccumulator();
      accumulator.push(Uint8List.fromList([0x00, 0x00, 0x00, 0x10]));
      expect(accumulator.bufferedBytes, 4);

      accumulator.clear();
      expect(accumulator.bufferedBytes, 0);
      expect(accumulator.drainFrames(), isEmpty);
    });
  });
}
