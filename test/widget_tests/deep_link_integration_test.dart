import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/app.dart';
import 'package:antigravity_remote/core/services/deep_link_service.dart';

void main() {
  group('Deep Link Integration Tests', () {
    testWidgets('incoming deep link triggers device binding, tab switch to workspace, and SnackBar', (tester) async {
      final deepLinkService = DeepLinkService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deepLinkServiceProvider.overrideWithValue(deepLinkService),
          ],
          child: const AntigravityRemoteApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // First navigate to another tab (e.g. Device Hub)
      await tester.tap(find.text('設備中樞'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Antigravity 控制台'), findsOneWidget);

      // Now simulate incoming deep link
      deepLinkService.handleRawUri(
        'https://accounts.google.com/AccountChooser?Email=tester@gmail.com&continue=https%3A%2F%2Fantigravity.google.com%2Fr%2Fdeep-link-target-9988%3Fp%3Dc%2Fmy-cascade-sess',
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Verify that the app automatically switched back to Workspace (CascadeChatView)
      expect(find.text('即時終端輸出 (Live Terminal)'), findsNothing);
      expect(find.text('Antigravity 控制台'), findsNothing);

      // Verify SnackBar was shown with device ID
      expect(find.textContaining('已透過 Deep Link 自動連線設備'), findsOneWidget);
      expect(find.textContaining('deep-link-ta...'), findsOneWidget);

      deepLinkService.dispose();
    });
  });
}
