import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/core/utils/utf8_chunk_decoder.dart';

void main() {
  group('Utf8ChunkDecoder Tests', () {
    test('decodes complete ASCII and multi-byte strings correctly', () {
      final decoder = Utf8ChunkDecoder();
      final bytes = utf8.encode('Hello 世界! 🚀');
      final result = decoder.decodeChunk(bytes);
      expect(result, 'Hello 世界! 🚀');
    });

    test(
      'recovers Chinese characters cut across packets without replacement character',
      () {
        final decoder = Utf8ChunkDecoder();
        final fullBytes = utf8.encode('測試跨分包解碼');

        // '測' has 3 bytes: 230, 184, 172
        expect(utf8.encode('測'), [230, 184, 172]);

        // Split right between byte 2 and byte 3 of '測'
        final chunk1 = fullBytes.sublist(0, 2); // only first 2 bytes of '測'
        final chunk2 = fullBytes.sublist(
          2,
          5,
        ); // 3rd byte of '測' + first 2 bytes of '試'
        final chunk3 = fullBytes.sublist(5); // remaining

        final part1 = decoder.decodeChunk(chunk1);
        expect(
          part1,
          isEmpty,
        ); // Incomplete sequence should not emit or corrupt

        final part2 = decoder.decodeChunk(chunk2);
        expect(part2, '測'); // '測' is now complete!

        final part3 = decoder.decodeChunk(chunk3);
        expect(part3, '試跨分包解碼');

        expect('$part1$part2$part3', '測試跨分包解碼');
      },
    );

    test('recovers 4-byte Emoji cut across packets', () {
      final decoder = Utf8ChunkDecoder();
      final emojiBytes = utf8.encode('🤖');
      expect(emojiBytes.length, 4);

      final chunk1 = emojiBytes.sublist(0, 1);
      final chunk2 = emojiBytes.sublist(1, 3);
      final chunk3 = emojiBytes.sublist(3, 4);

      expect(decoder.decodeChunk(chunk1), isEmpty);
      expect(decoder.decodeChunk(chunk2), isEmpty);
      expect(decoder.decodeChunk(chunk3), '🤖');
    });

    test('flush releases any final characters upon close', () {
      final decoder = Utf8ChunkDecoder();
      final bytes = utf8.encode('A');
      final r1 = decoder.decodeChunk(bytes);
      expect(r1, 'A');
      final r2 = decoder.flush();
      expect(r2, isEmpty);
    });
  });
}
