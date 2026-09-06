import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/core/models/user_interaction.dart';
import 'package:antigravity_remote/features/cascade/widgets/user_approval_dialog.dart';

void main() {
  group('UserApprovalDialog Widget Tests', () {
    testWidgets('renders destructive command with warning and approves with feedback', (tester) async {
      final req = UserInteractionRequest(
        interactionId: 'int-destruct-01',
        type: UserInteractionType.askPermission,
        title: '請求刪除敏感檔案',
        description: '即將執行清理指令',
        actionTarget: 'rm -rf ./build_cache',
        isDestructive: true,
        requestedAt: DateTime.now(),
      );

      bool? approvedResult;
      String? feedbackResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  UserApprovalDialog.show(
                    context,
                    request: req,
                    onRespond: (approved, feedback) {
                      approvedResult = approved;
                      feedbackResult = feedback;
                    },
                  );
                },
                child: const Text('打開審批'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打開審批'));
      await tester.pumpAndSettle();

      // Verify destructive warning banner
      expect(find.text('請求刪除敏感檔案'), findsOneWidget);
      expect(find.text('注意：此操作包含潛在破壞性指令，請謹慎審查！'), findsOneWidget);
      expect(find.text('rm -rf ./build_cache'), findsOneWidget);

      // Tap to expand feedback input
      await tester.tap(find.text('+ 附加補充指示或拒絕說明'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '確認可以清理快取');
      await tester.pumpAndSettle();

      // Tap Approve
      await tester.tap(find.text('核准執行 (Approve)'));
      await tester.pumpAndSettle();

      expect(approvedResult, isTrue);
      expect(feedbackResult, '確認可以清理快取');
    });

    testWidgets('rejects command correctly', (tester) async {
      final req = UserInteractionRequest(
        interactionId: 'int-reject-02',
        type: UserInteractionType.askPermission,
        title: '請求重啟服務',
        description: '重新載入服務',
        actionTarget: 'docker restart main_db',
        isDestructive: false,
        requestedAt: DateTime.now(),
      );

      bool? approvedResult;
      String? feedbackResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  UserApprovalDialog.show(
                    context,
                    request: req,
                    onRespond: (approved, feedback) {
                      approvedResult = approved;
                      feedbackResult = feedback;
                    },
                  );
                },
                child: const Text('打開審批'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打開審批'));
      await tester.pumpAndSettle();

      // Tap Reject directly
      await tester.tap(find.text('拒絕 (Reject)'));
      await tester.pumpAndSettle();

      expect(approvedResult, isFalse);
      expect(feedbackResult, isNull);
    });
  });
}
