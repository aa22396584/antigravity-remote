import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/app.dart';
import 'package:antigravity_remote/core/models/instance_info.dart';
import 'package:antigravity_remote/core/models/trajectory_step.dart';
import 'package:antigravity_remote/core/models/user_interaction.dart';
import 'package:antigravity_remote/features/cascade/widgets/thinking_card.dart';
import 'package:antigravity_remote/features/cascade/widgets/trajectory_step_card.dart';
import 'package:antigravity_remote/features/device/widgets/transport_badge.dart';

void main() {
  group('UI Widget Tests', () {
    testWidgets('TransportBadge renders P2P WebRTC correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TransportBadge(transport: TransportType.p2p, latencyMs: 14),
          ),
        ),
      );

      expect(find.text('P2P WebRTC'), findsOneWidget);
      expect(find.text('14ms'), findsOneWidget);
    });

    testWidgets('ThinkingCard renders thinking content and toggles collapse', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThinkingCard(
              thinking: '正在分析專案測試檔案...',
              isThinking: false,
              duration: Duration(seconds: 2),
            ),
          ),
        ),
      );

      expect(find.text('思考完畢 (耗時 2.0s)'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(find.text('正在分析專案測試檔案...'), findsOneWidget);
    });

    testWidgets(
      'TrajectoryStepCard renders tool name and inline approve button when waiting',
      (tester) async {
        final req = UserInteractionRequest(
          interactionId: 'test-req',
          type: UserInteractionType.askPermission,
          title: '請求終端指令授權',
          description: '執行測試',
          actionTarget: 'flutter test',
          requestedAt: DateTime.now(),
        );

        final step = TrajectoryStep(
          stepId: 'step-1',
          type: StepType.toolCall,
          toolName: 'run_command',
          summary: '執行單元測試',
          status: StepStatus.waitingUserInteraction,
          interaction: req,
          timestamp: DateTime.now(),
        );

        bool approvedCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TrajectoryStepCard(
                step: step,
                onApproval: (id, approved, feedback) {
                  approvedCalled = true;
                },
              ),
            ),
          ),
        );

        expect(find.text('執行單元測試'), findsOneWidget);
        expect(find.text('等待審批'), findsOneWidget);
        expect(find.text('直接核准'), findsOneWidget);

        // Tap directly approve button
        await tester.tap(find.text('直接核准'));
        await tester.pump();

        expect(approvedCalled, isTrue);
      },
    );

    testWidgets('AntigravityRemoteApp launches and switches tabs', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: AntigravityRemoteApp()),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Check BottomNavigationBar items
      expect(find.text('工作區'), findsOneWidget);
      expect(find.text('終端輸出'), findsOneWidget);
      expect(find.text('設備中樞'), findsOneWidget);

      // Switch to Terminal tab
      await tester.tap(find.text('終端輸出'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('即時終端輸出 (Live Terminal)'), findsOneWidget);

      // Switch to Device list tab
      await tester.tap(find.text('設備中樞'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Antigravity 控制台'), findsOneWidget);
      expect(find.text('已配對設備清單'), findsOneWidget);
    });
  });
}
