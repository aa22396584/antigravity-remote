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
  });
}
