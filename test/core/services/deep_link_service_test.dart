import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/core/services/deep_link_service.dart';
import 'package:antigravity_remote/core/services/qr_parser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeepLinkService Tests', () {
    late DeepLinkService service;

    setUp(() {
      service = DeepLinkService();
    });

    tearDown(() {
      service.dispose();
    });

    test('handleRawUri correctly emits target and returns ParsedRemoteTarget', () async {
      const url =
          'https://antigravity.google.com/r/inst-link-test-99?p=c/cascade-link-123';

      ParsedRemoteTarget? received;
      final sub = service.targetStream.listen((target) {
        received = target;
      });

      final parsed = service.handleRawUri(url);

      expect(parsed, isNotNull);
      expect(parsed!.instanceId, 'inst-link-test-99');
      expect(parsed.cascadeId, 'cascade-link-123');

      // Wait a tick for stream delivery
      await Future.delayed(Duration.zero);
      expect(received, isNotNull);
      expect(received!.instanceId, 'inst-link-test-99');
      expect(received!.cascadeId, 'cascade-link-123');

      await sub.cancel();
    });

    test('handleRawUri returns null on invalid URI without emitting', () async {
      bool called = false;
      final sub = service.targetStream.listen((_) {
        called = true;
      });

      final parsed = service.handleRawUri('https://invalid.com/random');
      expect(parsed, isNull);

      await Future.delayed(Duration.zero);
      expect(called, isFalse);

      await sub.cancel();
    });

    test('init calls onTargetReceived when target is handled', () async {
      ParsedRemoteTarget? targetFromCallback;

      await service.init(onTargetReceived: (target) {
        targetFromCallback = target;
      });

      service.handleRawUri('antigravity://r/instant-cold-start-id');

      await Future.delayed(Duration.zero);
      expect(targetFromCallback, isNotNull);
      expect(targetFromCallback!.instanceId, 'instant-cold-start-id');
    });

    test('deduplicates identical URIs arriving in rapid succession', () async {
      int emitCount = 0;
      final sub = service.targetStream.listen((_) {
        emitCount++;
      });

      const url = 'antigravity://r/dedup-test-device';
      service.handleRawUri(url);
      service.handleRawUri(url); // Rapid duplicate

      await Future.delayed(Duration.zero);
      expect(emitCount, 1);

      await sub.cancel();
    });
  });
}
