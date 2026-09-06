import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antigravity_remote/core/models/cascade_message.dart';
import 'package:antigravity_remote/core/models/trajectory_step.dart';
import 'package:antigravity_remote/core/models/user_interaction.dart';
import 'package:antigravity_remote/features/cascade/providers/cascade_provider.dart';

void main() {
  group('CascadeNotifier Tests', () {
    test('initializes with welcome message', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(cascadeProvider);
      expect(state.messages, isNotEmpty);
      expect(state.messages.first.content, contains('Antigravity 遠端控制中樞已就緒'));
    });

    test('sendPrompt adds user message and starts stream in demo mode', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cascadeProvider.notifier);
      await notifier.sendPrompt('請幫我執行測試');

      final state = container.read(cascadeProvider);
      expect(state.messages.any((m) => m.role == MessageRole.user && m.content == '請幫我執行測試'), isTrue);
    });

    test('handleApproval updates step status to completed or rejected', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cascadeProvider.notifier);

      // Manually inject a pending step
      final interactionReq = UserInteractionRequest(
        interactionId: 'test-req-1',
        type: UserInteractionType.askPermission,
        title: '請求授權',
        description: '執行測試',
        actionTarget: 'flutter test',
        requestedAt: DateTime.now(),
      );

      final step = TrajectoryStep(
        stepId: 'step-test',
        type: StepType.toolCall,
        toolName: 'run_command',
        summary: '測試步驟',
        status: StepStatus.waitingUserInteraction,
        interaction: interactionReq,
        timestamp: DateTime.now(),
      );

      final msg = CascadeMessage(
        id: 'msg-test',
        cascadeId: 'cascade-1',
        role: MessageRole.assistant,
        content: '',
        trajectorySteps: [step],
        timestamp: DateTime.now(),
      );

      // Add message into state
      notifier.state = notifier.state.copyWith(
        messages: [msg],
        pendingInteraction: interactionReq,
      );

      // Approve interaction
      notifier.handleApproval(
        interactionId: 'test-req-1',
        approved: true,
        feedback: 'OK',
      );

      final updatedState = container.read(cascadeProvider);
      expect(updatedState.pendingInteraction, isNull);
      final updatedStep = updatedState.messages.first.trajectorySteps.first;
      expect(updatedStep.status, StepStatus.completed);
      expect(updatedStep.interaction?.status, InteractionStatus.approved);
      expect(updatedStep.interaction?.userFeedback, 'OK');
    });

    test('clearConversation resets messages', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cascadeProvider.notifier);
      notifier.clearConversation();

      final state = container.read(cascadeProvider);
      expect(state.messages, isEmpty);
      expect(state.pendingInteraction, isNull);
    });
  });
}
