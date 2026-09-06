import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/features/device/views/connection_settings_view.dart';

void main() {
  group('ConnectionSettingsView Widget Tests', () {
    testWidgets(
      'renders all settings options and responds to user interaction',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: ConnectionSettingsView()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Header check
        expect(find.text('連線與雲端設定'), findsOneWidget);
        expect(find.text('離線展示與測試模式 (Demo Mode)'), findsOneWidget);
        expect(find.text('Google Cloud 端點伺服器'), findsOneWidget);
        expect(
          find.text('Google OAuth2 Access Token (Bearer)'),
          findsOneWidget,
        );
        expect(
          find.text('雙軌傳輸規格說明 (Dual-Transport Architecture)'),
          findsOneWidget,
        );

        // Verify Generate Test Token button exists in Demo mode
        expect(find.text('生成測試 Token'), findsOneWidget);
        expect(find.text('儲存 Token'), findsOneWidget);

        await tester.tap(find.text('生成測試 Token'));
        await tester.pumpAndSettle();
        expect(find.textContaining('mock-oauth-ya29'), findsOneWidget);

        // Save token draft
        await tester.tap(find.text('儲存 Token'));
        await tester.pumpAndSettle();
        expect(find.text('已安全儲存 OAuth Access Token'), findsOneWidget);

        // Verify Demo mode switch exists and toggle to Live Mode
        final switchFinder = find.byType(Switch);
        expect(switchFinder, findsOneWidget);
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        // In Live mode, '生成測試 Token' must be hidden (Issue #14)
        expect(find.text('生成測試 Token'), findsNothing);

        // Verify Environment options can be tapped
        expect(find.text('正式環境 (Production)'), findsOneWidget);
        expect(find.text('測試環境 (Daily / Staging)'), findsOneWidget);

        await tester.tap(find.text('測試環境 (Daily / Staging)'));
        await tester.pump(const Duration(milliseconds: 300));

        // Verify clear credentials button works
        expect(find.text('清除憑證 / 登出'), findsOneWidget);
        await tester.tap(find.text('清除憑證 / 登出'));
        await tester.pumpAndSettle();
        expect(find.text('已清除憑證並中斷連線'), findsOneWidget);
      },
    );
  });
}
