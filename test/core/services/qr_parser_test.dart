import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/core/services/qr_parser_service.dart';

void main() {
  group('QrParserService Tests', () {
    test('parse standard Google AccountChooser Antigravity QR URL', () {
      const url =
          'https://accounts.google.com/AccountChooser?Email=aa22396584@gmail.com&continue=https%3A%2F%2Fantigravity.google.com%2Fr%2F2114863e-6436-4398-b26f-8672c1bd5e4b-v2';

      final result = QrParserService.parse(url);

      expect(result, isNotNull);
      expect(result!.instanceId, '2114863e-6436-4398-b26f-8672c1bd5e4b-v2');
      expect(result.email, 'aa22396584@gmail.com');
    });

    test('parse Antigravity URL with Cascade ID parameter', () {
      const url =
          'https://antigravity.google.com/r/2114863e-6436-4398-b26f-8672c1bd5e4b-v2?p=c/cascade-session-8899';

      final result = QrParserService.parse(url);

      expect(result, isNotNull);
      expect(result!.instanceId, '2114863e-6436-4398-b26f-8672c1bd5e4b-v2');
      expect(result.cascadeId, 'cascade-session-8899');
    });

    test('parse antigravity:// custom scheme', () {
      const url = 'antigravity://remote/my-macbook-pro-m3';

      final result = QrParserService.parse(url);

      expect(result, isNotNull);
      expect(result!.instanceId, 'my-macbook-pro-m3');
    });

    test('parse JSON configuration string', () {
      const jsonStr =
          '{"instanceId": "2114863e-6436-4398-b26f-8672c1bd5e4b-v2", "hostname": "iml1sdemacbook-pro-4-local-deep-surge"}';

      final result = QrParserService.parse(jsonStr);

      expect(result, isNotNull);
      expect(result!.instanceId, '2114863e-6436-4398-b26f-8672c1bd5e4b-v2');
      expect(result.hostname, 'iml1sdemacbook-pro-4-local-deep-surge');
    });

    test('parse direct UUID or instanceId string', () {
      const id = '2114863e-6436-4398-b26f-8672c1bd5e4b-v2';

      final result = QrParserService.parse(id);

      expect(result, isNotNull);
      expect(result!.instanceId, id);
    });

    test('parse antigravity://r/{instanceId} scheme', () {
      const url = 'antigravity://r/2114863e-6436-4398-b26f-8672c1bd5e4b-v2';

      final result = QrParserService.parse(url);

      expect(result, isNotNull);
      expect(result!.instanceId, '2114863e-6436-4398-b26f-8672c1bd5e4b-v2');
    });

    test('parse antigravity://connect with query parameters', () {
      const url =
          'antigravity://connect?instanceId=device-mesh-99&email=dev@antigravity.io&hostname=m4-max';

      final result = QrParserService.parse(url);

      expect(result, isNotNull);
      expect(result!.instanceId, 'device-mesh-99');
      expect(result.email, 'dev@antigravity.io');
      expect(result.hostname, 'm4-max');
    });

    test('parse antigravity-remote:// scheme', () {
      const url = 'antigravity-remote://remote/cluster-node-01';

      final result = QrParserService.parse(url);

      expect(result, isNotNull);
      expect(result!.instanceId, 'cluster-node-01');
    });

    test('parse antigravity:// direct instanceId host', () {
      const url = 'antigravity://2114863e-6436-4398-b26f-8672c1bd5e4b-v2';

      final result = QrParserService.parse(url);

      expect(result, isNotNull);
      expect(result!.instanceId, '2114863e-6436-4398-b26f-8672c1bd5e4b-v2');
    });

    test('return null on empty or invalid input', () {
      expect(QrParserService.parse(''), isNull);
      expect(QrParserService.parse('   '), isNull);
      expect(QrParserService.parse('https://example.com/other/path'), isNull);
    });

    test('parse double-encoded continue URL from Google AccountChooser', () {
      final result = QrParserService.parse(
        'https://accounts.google.com/AccountChooser?Email=tester@gmail.com&continue=https%253A%252F%252Fantigravity.google.com%252Fr%252Fdouble-encoded-123%253Fp%253Dc%252Fcasc-session-456',
      );
      expect(result, isNotNull);
      expect(result!.instanceId, 'double-encoded-123');
      expect(result.cascadeId, 'casc-session-456');
      expect(result.email, 'tester@gmail.com');
    });

    test('parse continue URL containing custom antigravity:// scheme', () {
      final result = QrParserService.parse(
        'https://accounts.google.com/AccountChooser?Email=tester@gmail.com&continue=antigravity%3A%2F%2Fr%2Fcustom-continue-456',
      );
      expect(result, isNotNull);
      expect(result!.instanceId, 'custom-continue-456');
    });

    test('parse URL wrapped in quotes, backticks or angle brackets', () {
      final r1 = QrParserService.parse(
        '"https://antigravity.google.com/r/quoted-id-789"',
      );
      expect(r1, isNotNull);
      expect(r1!.instanceId, 'quoted-id-789');

      final r2 = QrParserService.parse('<antigravity://r/bracket-id-789>');
      expect(r2, isNotNull);
      expect(r2!.instanceId, 'bracket-id-789');

      final r3 = QrParserService.parse('`antigravity://r/backtick-id-789`');
      expect(r3, isNotNull);
      expect(r3!.instanceId, 'backtick-id-789');
    });

    test('parse single-slash custom scheme (antigravity:/r/...)', () {
      final result = QrParserService.parse('antigravity:/r/single-slash-id');
      expect(result, isNotNull);
      expect(result!.instanceId, 'single-slash-id');
    });

    test('parse instance_id with underscores from connect query', () {
      final result = QrParserService.parse(
        'antigravity://connect?instance_id=underscore-id-999',
      );
      expect(result, isNotNull);
      expect(result!.instanceId, 'underscore-id-999');
    });

    test('parse cascadeId with leading /c/ path in p parameter', () {
      final result = QrParserService.parse(
        'https://antigravity.google.com/r/test-id-111?p=/c/casc-123',
      );
      expect(result, isNotNull);
      expect(result!.cascadeId, 'casc-123');
    });

    test(
      'single quote and bare punctuation do not crash with RangeError (Issue #16)',
      () {
        expect(QrParserService.parse("'"), isNull);
        expect(QrParserService.parse("''"), isNull);
        expect(QrParserService.parse("'''"), isNull);
        expect(QrParserService.parse('"'), isNull);
        expect(QrParserService.parse('`'), isNull);
        expect(QrParserService.parse('<'), isNull);
        expect(QrParserService.parse('>'), isNull);
      },
    );

    test('rejects lookalike domains and userinfo spoofing (Issue #16)', () {
      // Lookalike domain suffix
      expect(
        QrParserService.parse(
          'https://antigravity.google.com.evil-attacker.com/r/target-123',
        ),
        isNull,
      );
      // Userinfo spoofing
      expect(
        QrParserService.parse(
          'https://antigravity.google.com@evil.com/r/target-123',
        ),
        isNull,
      );
      // Query injection without authentic domain
      expect(
        QrParserService.parse(
          'https://evil.com/search?q=https://antigravity.google.com/r/target-123',
        ),
        isNull,
      );
    });

    test('rejects JSON with non-string or malformed ID types (Issue #16)', () {
      expect(QrParserService.parse('{"instanceId": true}'), isNull);
      expect(QrParserService.parse('{"instanceId": [1, 2, 3]}'), isNull);
      expect(
        QrParserService.parse('{"instanceId": {"nested": "val"}}'),
        isNull,
      );
    });

    test(
      'rejects inputs exceeding maximum size and bounded redirect recursion',
      () {
        final hugeStr = 'a' * 5000;
        expect(QrParserService.parse(hugeStr), isNull);

        // Deep redirect chain > 3 levels
        String deepUrl = 'https://antigravity.google.com/r/valid-id-123';
        for (int i = 0; i < 5; i++) {
          deepUrl =
              'https://accounts.google.com/AccountChooser?continue=${Uri.encodeComponent(deepUrl)}';
        }
        expect(QrParserService.parse(deepUrl, depth: 4), isNull);
      },
    );
  });
}
