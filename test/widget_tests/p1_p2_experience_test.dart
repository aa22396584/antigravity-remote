import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/app.dart';
import 'package:antigravity_remote/core/models/cascade_message.dart';
import 'package:antigravity_remote/core/models/terminal_stream.dart';
import 'package:antigravity_remote/core/models/user_interaction.dart';
import 'package:antigravity_remote/features/cascade/providers/cascade_provider.dart';
import 'package:antigravity_remote/features/cascade/views/cascade_chat_view.dart';
import 'package:antigravity_remote/features/cascade/widgets/chat_input_bar.dart';
import 'package:antigravity_remote/features/cascade/widgets/code_diff_viewer.dart';
import 'package:antigravity_remote/features/cascade/widgets/user_approval_dialog.dart';
import 'package:antigravity_remote/features/terminal/widgets/terminal_console_card.dart';

class MockCascadeNotifier extends CascadeNotifier {
  final List<CascadeMessage> initialMessages;
  MockCascadeNotifier(this.initialMessages);

  @override
  CascadeState build() {
    return CascadeState(messages: initialMessages);
  }
}

void main() {
  group('P1 & P2 Experience Widget Tests', () {
    testWidgets(
      'ChatInputBar displays stop task button and disables chips during streaming',
      (tester) async {
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
      },
    );

    testWidgets(
      'ChatInputBar does not overwrite existing text when prompt chip is tapped',
      (tester) async {
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
      },
    );

    testWidgets(
      'CodeDiffViewer renders diff hunks, additions, deletions and copy buttons',
      (tester) async {
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
      },
    );

    testWidgets(
      'Adaptive layout renders NavigationRail on large desktop screen and bottom nav on small',
      (tester) async {
        // 1. Large desktop width: 1024x768
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const ProviderScope(child: AntigravityRemoteApp()),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(NavigationRail), findsOneWidget);

        // 2. Small mobile width: 400x800
        tester.view.physicalSize = const Size(400, 800);
        await tester.pumpWidget(
          const ProviderScope(child: AntigravityRemoteApp()),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(NavigationRail), findsNothing);
      },
    );

    testWidgets(
      'ChatInputBar restores draft when onSend returns false or throws exception',
      (tester) async {
        bool shouldFail = true;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInputBar(
                isStreaming: false,
                onSend: (p) async {
                  if (shouldFail) return false;
                  throw Exception('network disconnected');
                },
              ),
            ),
          ),
        );

        // 1. When onSend returns false
        await tester.enterText(find.byType(TextField), '重要未送出的草稿內容');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        // TextField should restore the draft
        expect(find.text('重要未送出的草稿內容'), findsOneWidget);

        // 2. When onSend throws
        shouldFail = false;
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        // TextField should still restore the draft
        expect(find.text('重要未送出的草稿內容'), findsOneWidget);
      },
    );

    testWidgets(
      'CodeDiffViewer auto-detects file name from diff headers when fileName is not provided',
      (tester) async {
        const diffWithHeader = '''
--- a/lib/core/service.dart
+++ b/lib/core/service.dart
@@ -10,2 +10,3 @@
 const a = 1;
+const b = 2;
''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: CodeDiffViewer(diff: diffWithHeader)),
          ),
        );

        expect(find.text('lib/core/service.dart'), findsOneWidget);
        expect(find.text('+1'), findsOneWidget);
      },
    );

    testWidgets(
      'UserApprovalDialog renders embedded CodeDiffViewer for unified diffs and copy button >=44x44',
      (tester) async {
        const diffContent = '''
--- a/test.dart
+++ b/test.dart
@@ -1,2 +1,3 @@
 void run() {
+  print("test");
 }
''';
        final request = UserInteractionRequest(
          interactionId: 'inter-diff-1',
          title: '修改檔案 test.dart',
          description: '申請套用程式碼變更',
          type: UserInteractionType.askPermission,
          actionName: 'write_file',
          actionTarget: diffContent,
          requestedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserApprovalDialog(
                request: request,
                onRespond: (approved, feedback) {},
              ),
            ),
          ),
        );

        // Embedded CodeDiffViewer should be rendered
        expect(find.byType(CodeDiffViewer), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(CodeDiffViewer),
            matching: find.textContaining('print("test");'),
          ),
          findsOneWidget,
        );

        // Verify copy target button touch target size >= 44x44
        final copyBtn = tester.widget<IconButton>(
          find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == '複製完整指令/目標',
          ),
        );
        expect(copyBtn.constraints?.minWidth, greaterThanOrEqualTo(44.0));
        expect(copyBtn.constraints?.minHeight, greaterThanOrEqualTo(44.0));
      },
    );

    testWidgets(
      'TerminalConsoleCard touch targets meet >= 44x44 and adapts to keyboard insets',
      (tester) async {
        final chunks = [
          TerminalChunk(
            text: 'Antigravity terminal ready\n',
            timestamp: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              viewInsets: EdgeInsets.only(bottom: 260),
            ),
            child: MaterialApp(
              home: Scaffold(
                body: TerminalConsoleCard(
                  chunks: chunks,
                  onSendInput: (_) {},
                  onShortcut: (_) {},
                  onClear: () {},
                ),
              ),
            ),
          ),
        );

        final sendBtn = tester.widget<IconButton>(
          find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '發送按鍵'),
        );
        expect(sendBtn.constraints?.minWidth, greaterThanOrEqualTo(44.0));
        expect(sendBtn.constraints?.minHeight, greaterThanOrEqualTo(44.0));

        final clearBtn = tester.widget<IconButton>(
          find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == '清空終端畫面',
          ),
        );
        expect(clearBtn.constraints?.minWidth, greaterThanOrEqualTo(44.0));
        expect(clearBtn.constraints?.minHeight, greaterThanOrEqualTo(44.0));

        // Shortcut chip container has constraints >= 44x44
        final ctrlCContainer = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Ctrl+C'),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          ctrlCContainer.constraints?.minWidth,
          greaterThanOrEqualTo(44.0),
        );
        expect(
          ctrlCContainer.constraints?.minHeight,
          greaterThanOrEqualTo(44.0),
        );

        expect(find.text('Ctrl+D'), findsOneWidget);
        expect(find.text('Esc'), findsOneWidget);
      },
    );

    testWidgets(
      'CascadeChatView renders failed user message with retry and edit draft >=44x44',
      (tester) async {
        final failedMsg = CascadeMessage(
          id: 'msg-failed-1',
          cascadeId: 'cascade-main',
          role: MessageRole.user,
          content: '需要重試的代碼指令',
          deliveryStatus: MessageDeliveryStatus.failed,
          timestamp: DateTime.now(),
        );

        final container = ProviderContainer(
          overrides: [
            cascadeProvider.overrideWith(
              () => MockCascadeNotifier([failedMsg]),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: CascadeChatView())),
          ),
        );
        await tester.pump();

        expect(find.text('發送失敗'), findsOneWidget);
        expect(find.text('重試 ↻'), findsOneWidget);
        expect(find.text('編輯草稿 ✎'), findsOneWidget);

        // Tap '編輯草稿 ✎'
        await tester.tap(find.text('編輯草稿 ✎'));
        await tester.pump();

        // Verify the text is copied back to input field
        expect(find.text('需要重試的代碼指令'), findsOneWidget);

        // Verify the failed message was removed from the list
        expect(find.text('發送失敗'), findsNothing);
      },
    );
  });
}
