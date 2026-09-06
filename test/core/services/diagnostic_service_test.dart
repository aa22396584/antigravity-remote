import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/core/services/diagnostic_service.dart';

void main() {
  group('DiagnosticService Tests', () {
    setUp(() {
      DiagnosticService.instance.clear();
    });

    test('redacts Bearer tokens and ya29 OAuth credentials (Issue #32)', () {
      const raw = 'Sending request with Bearer ya29.a0AfH6SMA987654321-sensitive-token to endpoint';
      final redacted = DiagnosticService.redact(raw);

      expect(redacted, isNot(contains('ya29.a0AfH6SMA987654321-sensitive-token')));
      expect(redacted, contains('[REDACTED_TOKEN]'));
    });

    test('redacts Authorization header values in JSON/text (Issue #32)', () {
      const raw = '{"Authorization": "secret_key_12345678"}';
      final redacted = DiagnosticService.redact(raw);

      expect(redacted, isNot(contains('secret_key_12345678')));
      expect(redacted, contains('[REDACTED]'));
    });

    test('ring buffer caps maximum entries and evicts oldest (Issue #32)', () {
      for (int i = 0; i < 150; i++) {
        DiagnosticService.instance.log('Log message $i');
      }

      final entries = DiagnosticService.instance.getEntries();
      expect(entries.length, equals(DiagnosticService.maxEntries));
      expect(entries.first.message, contains('Log message 30'));
      expect(entries.last.message, contains('Log message 149'));
    });

    test('exportReport generates sanitized formatted report', () {
      DiagnosticService.instance.log('User connected with Bearer super_secret_token');
      final report = DiagnosticService.instance.exportReport(
        appVersion: '1.0.0+1',
        isDemoMode: false,
        environment: 'production',
        deviceCount: 2,
      );

      expect(report, contains('Antigravity Remote Diagnostic Report'));
      expect(report, contains('Mode: Live Mode'));
      expect(report, isNot(contains('super_secret_token')));
      expect(report, contains('[REDACTED_TOKEN]'));
    });
  });
}
