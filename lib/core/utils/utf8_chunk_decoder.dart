import 'dart:convert';

class _SyncStringSink extends StringConversionSink {
  final void Function(String) onChunk;
  _SyncStringSink(this.onChunk);

  @override
  void add(String str) {
    if (str.isNotEmpty) onChunk(str);
  }

  @override
  void addSlice(String chunk, int start, int end, bool isLast) {
    if (start < end) {
      onChunk(chunk.substring(start, end));
    }
  }

  @override
  void close() {}
}

/// 支援跨分包 (Cross-packet / Fragmentation) 的狀態化 UTF-8 解碼器
///
/// 解決 TCP / WebRTC DataChannel 分包時，多位元組字元（例如中文 3 位元組、Emoji 4 位元組）
/// 在中間被截斷導致的破字亂碼 (\uFFFD) 問題。
class Utf8ChunkDecoder {
  final bool allowMalformed;
  late ByteConversionSink _sink;
  final StringBuffer _buffer = StringBuffer();

  Utf8ChunkDecoder({this.allowMalformed = true}) {
    _resetSink();
  }

  void _resetSink() {
    _sink = Utf8Decoder(allowMalformed: allowMalformed).startChunkedConversion(
      _SyncStringSink((chunk) {
        _buffer.write(chunk);
      }),
    );
  }

  /// 解碼傳入的位元組分片，並回傳當前所有已完整組裝解碼的字串
  String decodeChunk(List<int> chunk) {
    if (chunk.isEmpty) return '';
    _buffer.clear();
    _sink.addSlice(chunk, 0, chunk.length, false);
    return _buffer.toString();
  }

  /// 關閉當前串流並強制解碼剩餘殘留位元組（若有）
  String flush() {
    _buffer.clear();
    _sink.close();
    final remaining = _buffer.toString();
    _resetSink();
    return remaining;
  }

  /// 重設解碼器內部狀態
  void reset() {
    _buffer.clear();
    _resetSink();
  }
}
