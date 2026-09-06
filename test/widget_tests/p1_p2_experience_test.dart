import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/app.dart';
import 'package:antigravity_remote/features/cascade/widgets/chat_input_bar.dart';
import 'package:antigravity_remote/features/cascade/widgets/code_diff_viewer.dart';

void main() {
  group('P1 & P2 Experience Widget Tests', () {
    testWidgets('ChatInputBar displays stop task button and disables chips during streaming', (tester) async {
      bool stopCalled = false;
      String? sentPrompt;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputBar(
              isStreaming: true,
              onStop: () => stopCalled = true,
              onSend: (p) => sentPrompt = p,
            ),
          ),
        ),
      );

      // Verify Stop button is visible during streaming
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byTooltip('中止遠端任務 (Stop Task)'), findsOneWidget);

      // Tap stop button
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pump();
      expect(stopCalled, isTrue);

      // Tapping prompt chip during streaming should NOT trigger send or change text
      await tester.tap(find.text('繼續執行'));
      await tester.pump();
      expect(sentPrompt, isNull);
    });

    testWidgets('ChatInputBar does not overwrite existing text when prompt chip is tapped', (tester) async {
      String? sentPrompt;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputBar(
              isStreaming: false,
              onSend: (p) => sentPrompt = p,
            ),
          ),
        ),
      );

      // Enter user text
      await tester.enterText(find.byType(TextField), '我的自定義提示詞');
      await tester.pump();

      // Tap quick prompt chip
      await tester.tap(find.text('繼續執行'));
      await tester.pump();

      // TextField should preserve '我的自定義提示詞' (appends, does not overwrite)
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '我的自定義提示詞\n繼續執行');

      // Tap send button
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(sentPrompt, contains('我的自定義提示詞'));
    });

    testWidgets('CodeDiffViewer renders diff hunks, additions, deletions and copy buttons', (tester) async {
      const sampleDiff = '''
--- a/example.dart
+++ b/example.dart
@@ -1,3 +1,4 @@
 void main() {
-  print("old line");
+  print("new line 1");
+  print("new line 2");
 }
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CodeDiffViewer(
              diff: sampleDiff,
              fileName: 'lib/example.dart',
            ),
          ),
        ),
      );

      expect(find.text('lib/example.dart'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      expect(find.textContaining('print("old line");'), findsOneWidget);
      expect(find.textContaining('print("new line 1");'), findsOneWidget);
      expect(find.textContaining('print("new line 2");'), findsOneWidget);

      // Tooltips for copy buttons
      expect(find.byTooltip('複製完整 Diff'), findsOneWidget);
      expect(find.byTooltip('複製變更內容'), findsOneWidget);
    });

    testWidgets('Adaptive layout renders NavigationRail on large desktop screen and bottom nav on small', (tester) async {
      // 1. Large desktop width: 1024x768
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: AntigravityRemoteApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(NavigationRail), findsOneWidget);

      // 2. Small mobile width: 400x800
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpWidget(
        const ProviderScope(
          child: AntigravityRemoteApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(NavigationRail), findsNothing);
    });
  });
}
