import 'dart:collection';

class DiagnosticLogEntry {
  final DateTime timestamp;
  final String level;
  final String message;
  final String? category;

  DiagnosticLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.category,
  });

  @override
  String toString() {
    final cat = category != null ? '[$category] ' : '';
    return '[${timestamp.toIso8601String()}] [$level] $cat$message';
  }
}

/// 安全診斷記錄服務 (Issue #32)
/// 具備固定容量 Ring Buffer 與自動敏感資訊遮蔽 (Redaction)
class DiagnosticService {
  static final DiagnosticService instance = DiagnosticService._();
  DiagnosticService._();

  static const int maxEntries = 120;
  final Queue<DiagnosticLogEntry> _logs = Queue<DiagnosticLogEntry>();

  /// 記錄日誌並自動遮蔽敏感憑證
  void log(String message, {String level = 'INFO', String? category}) {
    final sanitized = redact(message);
    if (_logs.length >= maxEntries) {
      _logs.removeFirst();
    }
    _logs.add(
      DiagnosticLogEntry(
        timestamp: DateTime.now(),
        level: level,
        message: sanitized,
        category: category,
      ),
    );
  }

  /// 敏感資訊遮蔽過濾器
  /// 自動替換 Bearer Token、ya29 OAuth 憑證、密碼與私鑰特徵字串
  static String redact(String input) {
    var result = input;
    // 遮蔽 Bearer Token
    result = result.replaceAllMapped(
      RegExp(r'(Bearer\s+)[a-zA-Z0-9_\-\.]{10,}', caseSensitive: false),
      (m) => '${m.group(1)}[REDACTED_TOKEN]',
    );
    // 遮蔽 Google ya29. Token
    result = result.replaceAllMapped(
      RegExp(r'ya29\.[a-zA-Z0-9_\-]{15,}'),
      (m) => 'ya29.[REDACTED_OAUTH]',
    );
    // 遮蔽 Authorization header
    result = result.replaceAllMapped(
      RegExp(r'''(["']?authorization["']?\s*:\s*["'])([^"'\r\n]+)(["'])''', caseSensitive: false),
      (m) => '${m.group(1)}[REDACTED]${m.group(3)}',
    );
    // 遮蔽 Cookie 敏感資訊 (Issue #32)
    result = result.replaceAllMapped(
      RegExp(r'''(["']?cookie["']?\s*:\s*["'])([^"'\r\n]+)(["'])''', caseSensitive: false),
      (m) => '${m.group(1)}[REDACTED_COOKIE]${m.group(3)}',
    );
    // 遮蔽 Password 敏感資訊
    result = result.replaceAllMapped(
      RegExp(r'''(["']?password["']?\s*:\s*["'])([^"'\r\n]+)(["'])''', caseSensitive: false),
      (m) => '${m.group(1)}[REDACTED_PASSWORD]${m.group(3)}',
    );
    // 遮蔽 private key 特徵
    result = result.replaceAllMapped(
      RegExp(r'-----BEGIN [A-Z ]+ PRIVATE KEY-----[^-]+-----END [A-Z ]+ PRIVATE KEY-----'),
      (m) => '[REDACTED_PRIVATE_KEY]',
    );
    return result;
  }

  List<DiagnosticLogEntry> getEntries() => List.unmodifiable(_logs);

  void clear() => _logs.clear();

  String exportReport({
    required String appVersion,
    required bool isDemoMode,
    required String environment,
    required int deviceCount,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('=== Antigravity Remote Diagnostic Report ===');
    buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    buffer.writeln('App Version: $appVersion');
    buffer.writeln('Mode: ${isDemoMode ? "Demo Mode" : "Live Mode"}');
    buffer.writeln('Environment: $environment');
    buffer.writeln('Configured Devices: $deviceCount');
    buffer.writeln('Notice: All authentication tokens and private keys are sanitized.');
    buffer.writeln('--------------------------------------------');
    buffer.writeln('Recent Events (${_logs.length}):');
    for (final entry in _logs) {
      buffer.writeln(entry.toString());
    }
    buffer.writeln('============================================');
    return buffer.toString();
  }
}
