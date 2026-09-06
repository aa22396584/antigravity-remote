import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/app.dart';
import 'package:antigravity_remote/core/services/deep_link_service.dart';

void main() {
  group('Deep Link Integration Tests', () {
    testWidgets(
      'incoming deep link triggers device binding, tab switch to workspace, and SnackBar',
      (tester) async {
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
      },
    );

    testWidgets(
      'incoming deep link while modal route is open pops back to root workspace',
      (tester) async {
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

        // 1. Go to Device Hub
        await tester.tap(find.text('設備中樞'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Antigravity 控制台'), findsOneWidget);

        // 2. Open Settings modal view
        expect(find.byTooltip('雲端與連線設定'), findsOneWidget);
        await tester.tap(find.byTooltip('雲端與連線設定'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('連線與雲端設定'), findsOneWidget);

        // 3. Deep link arrives while user is inside settings modal
        deepLinkService.handleRawUri(
          'antigravity://r/modal-intercept-device?email=user@test.io',
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // 4. Verify settings modal was dismissed and user is on Workspace
        expect(find.text('連線與雲端設定'), findsNothing);
        expect(
          find.textContaining('Antigravity (user@test.io)'),
          findsOneWidget,
        );

        deepLinkService.dispose();
      },
    );

    testWidgets(
      'in-app QR pairing via manual input binds device, sets email name, and switches to workspace',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: AntigravityRemoteApp()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 1. Switch to Device Hub
        await tester.tap(find.text('設備中樞'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 2. Open QR Scanner View
        await tester.tap(find.text('掃描 QR 配對'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('掃描 Antigravity 配對碼'), findsOneWidget);

        // 3. Open manual input dialog
        await tester.tap(find.text('手動輸入配對網址或 ID'));
        await tester.pump();
        expect(find.text('手動輸入配對資訊'), findsOneWidget);

        // 4. Enter Google AccountChooser QR link with email & cascade ID
        await tester.enterText(
          find.byType(TextField),
          'https://accounts.google.com/AccountChooser?Email=engineer@google.com&continue=https%3A%2F%2Fantigravity.google.com%2Fr%2Fpaired-device-8888%3Fp%3Dc%2Fagent-cascade-999',
        );
        await tester.pump();

        // 5. Submit manual binding
        await tester.tap(find.text('確認綁定'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // 6. Verify automatically navigated to Workspace with email name
        expect(find.text('掃描 Antigravity 配對碼'), findsNothing);
        expect(
          find.textContaining('Antigravity (engineer@google.com)'),
          findsOneWidget,
        );
        expect(find.textContaining('成功配對並切換設備'), findsOneWidget);
      },
    );
  });
}
