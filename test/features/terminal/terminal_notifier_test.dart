import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antigravity_remote/features/terminal/providers/terminal_provider.dart';

void main() {
  group('TerminalNotifier Tests', () {
    test('initializes with banner chunk', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(terminalProvider);
      expect(state.chunks, isNotEmpty);
      expect(state.chunks.first.text, contains('Antigravity Remote Terminal Bridge'));
    });

    test('sendInput appends input chunk', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(terminalProvider.notifier);
      await notifier.sendInput('echo "Hello Antigravity"');

      final state = container.read(terminalProvider);
      expect(state.chunks.any((c) => c.text.contains('echo "Hello Antigravity"')), isTrue);
    });

    test('sendShortcut sends special keys', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(terminalProvider.notifier);
      notifier.sendShortcut('Ctrl+C');

      final state = container.read(terminalProvider);
      expect(state.chunks.any((c) => c.text.contains('\x03')), isTrue);
    });

    test('clear resets chunks list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(terminalProvider.notifier);
      notifier.clear();

      final state = container.read(terminalProvider);
      expect(state.chunks, isEmpty);
    });
  });
}
