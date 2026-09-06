import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antigravity_remote/core/models/cascade_message.dart';
import 'package:antigravity_remote/core/models/instance_info.dart';
import 'package:antigravity_remote/core/models/trajectory_step.dart';
import 'package:antigravity_remote/core/models/user_interaction.dart';
import 'package:antigravity_remote/core/services/remote_control_service.dart';
import 'package:antigravity_remote/features/cascade/providers/cascade_provider.dart';
import 'package:antigravity_remote/features/device/providers/device_provider.dart';
import '../../test_harness/mock_transport_harness.dart';

void main() {
  group('P0 #4: 審批過早顯示成功防禦測試 (Premature Approval Success Prevention Tests)', () {
    test('retains pending interaction and preserves step status when remote approval RPC fails', () async {
      final harness = MockTransportHarness();
      addTearDown(harness.dispose);

      // 模擬遠端 RPC 執行失敗 (例如：主機拒絕、逾時、網路斷開)
      harness.unaryError = TimeoutException('遠端主機無回應 (ConnectRPC Timeout)');

      final container = ProviderContainer(
        overrides: [
          remoteControlServiceProvider.overrideWithValue(
            RemoteControlService(
              isDemoMode: false,
              transportManager: harness,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cascadeProvider.notifier);

      final interactionReq = UserInteractionRequest(
        interactionId: 'req-critical-rm',
        type: UserInteractionType.askPermission,
        title: '請求刪除敏感目錄',
        description: '即將執行危險清理指令',
        actionTarget: 'rm -rf /tmp/data',
        isDestructive: true,
        requestedAt: DateTime.now(),
      );

      final step = TrajectoryStep(
        stepId: 'step-rm-01',
        type: StepType.toolCall,
        toolName: 'run_command',
        summary: '執行刪除指令',
        status: StepStatus.waitingUserInteraction,
        interaction: interactionReq,
        timestamp: DateTime.now(),
      );

      final initialMsg = CascadeMessage(
        id: 'msg-approval-test',
        cascadeId: 'cascade-1',
        role: MessageRole.assistant,
        content: '準備執行指令...',
        trajectorySteps: [step],
        timestamp: DateTime.now(),
      );

      notifier.state = notifier.state.copyWith(
        messages: [initialMsg],
        pendingInteraction: interactionReq,
      );

      // 使用者點擊核准執行，但遠端 RPC 發生異常
      await expectLater(
        notifier.handleApproval(
          interactionId: 'req-critical-rm',
          approved: true,
          feedback: '確認刪除',
        ),
        throwsA(isA<TimeoutException>()),
      );

      // 核心安全斷言 (P0 #4)：
      // 1. 待審批項絕不能被清除！避免使用者誤判為已經核准成功
      final currentState = container.read(cascadeProvider);
      expect(currentState.pendingInteraction, isNotNull, reason: '遠端失敗時必須保留待審批狀態');
      expect(currentState.pendingInteraction?.interactionId, 'req-critical-rm');

      // 2. 步驟狀態絕不可被標註為 StepStatus.completed！必須維持 waitingUserInteraction
      final currentStep = currentState.messages.first.trajectorySteps.first;
      expect(currentStep.status, StepStatus.waitingUserInteraction, reason: '遠端未確認前絕不可標註為 completed');

      // 3. 錯誤訊息必須正確通知使用者
      expect(currentState.errorMessage, contains('審批提交失敗，遠端未確認執行'));
    });

    test('updates step status to completed and clears pending interaction ONLY when remote RPC confirms success', () async {
      final harness = MockTransportHarness();
      addTearDown(harness.dispose);

      // 模擬遠端 RPC 成功確認 (200 OK)
      harness.unaryError = null;

      final container = ProviderContainer(
        overrides: [
          remoteControlServiceProvider.overrideWithValue(
            RemoteControlService(
              isDemoMode: false,
              transportManager: harness,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cascadeProvider.notifier);

      final interactionReq = UserInteractionRequest(
        interactionId: 'req-safe-run',
        type: UserInteractionType.askPermission,
        title: '請求執行單元測試',
        description: '執行測試',
        actionTarget: 'flutter test',
        requestedAt: DateTime.now(),
      );

      final step = TrajectoryStep(
        stepId: 'step-run-01',
        type: StepType.toolCall,
        toolName: 'run_command',
        summary: '執行測試',
        status: StepStatus.waitingUserInteraction,
        interaction: interactionReq,
        timestamp: DateTime.now(),
      );

      final initialMsg = CascadeMessage(
        id: 'msg-ok-test',
        cascadeId: 'cascade-1',
        role: MessageRole.assistant,
        content: '',
        trajectorySteps: [step],
        timestamp: DateTime.now(),
      );

      notifier.state = notifier.state.copyWith(
        messages: [initialMsg],
        pendingInteraction: interactionReq,
      );

      // 使用者點擊核准執行
      await notifier.handleApproval(
        interactionId: 'req-safe-run',
        approved: true,
        feedback: 'Proceed',
      );

      // 遠端成功確認後之斷言
      final state = container.read(cascadeProvider);
      expect(state.pendingInteraction, isNull, reason: '遠端確認成功後方可清除待審批');
      final finishedStep = state.messages.first.trajectorySteps.first;
      expect(finishedStep.status, StepStatus.completed);
      expect(finishedStep.interaction?.status, InteractionStatus.approved);
      expect(state.errorMessage, isNull);
    });
  });

  group('P0 #1: 裝置切換與畫面目標一致性測試 (Target Inconsistency on Device Switch)', () {
    test('switching active device clears old conversation and pending approvals', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final deviceNotifier = container.read(deviceProvider.notifier);
      final cascadeNotifier = container.read(cascadeProvider.notifier);

      // 設備 A
      final devA = InstanceInfo(
        instanceId: 'dev-mac-a',
        uuid: 'uuid-mac-a',
        name: 'Work Mac A',
        status: InstanceConnectionStatus.connected,
        transport: TransportType.p2p,
        lastSeen: DateTime.now(),
      );

      // 設備 B
      final devB = InstanceInfo(
        instanceId: 'dev-mac-b',
        uuid: 'uuid-mac-b',
        name: 'Work Mac B',
        status: InstanceConnectionStatus.connected,
        transport: TransportType.p2p,
        lastSeen: DateTime.now(),
      );

      await deviceNotifier.addDevice(instanceId: devA.instanceId, name: devA.name);
      await deviceNotifier.addDevice(instanceId: devB.instanceId, name: devB.name);

      // 先選中設備 A，並注入設備 A 的對話與待審批項
      await deviceNotifier.selectDevice(devA);

      final devAPendingReq = UserInteractionRequest(
        interactionId: 'req-on-device-a',
        type: UserInteractionType.askPermission,
        title: '機器 A 待審批',
        description: '機敏操作',
        actionTarget: 'git reset --hard',
        requestedAt: DateTime.now(),
      );

      cascadeNotifier.state = cascadeNotifier.state.copyWith(
        messages: [
          CascadeMessage(
            id: 'msg-dev-a',
            cascadeId: 'cascade-dev-a',
            role: MessageRole.assistant,
            content: '這是機器 A 上的會話內容',
            timestamp: DateTime.now(),
          ),
        ],
        pendingInteraction: devAPendingReq,
      );

      expect(container.read(cascadeProvider).messages, isNotEmpty);
      expect(container.read(cascadeProvider).pendingInteraction, isNotNull);

      // 切換至設備 B！
      await deviceNotifier.selectDevice(devB);

      // 核心安全斷言 (P0 #1)：
      // 切換到機器 B 後，機器 A 的舊會話與待審批項必須被原子性清空，絕不能出現在機器 B 的畫面上！
      final newState = container.read(cascadeProvider);
      expect(newState.messages, isEmpty, reason: '切換設備時必須清理舊畫面訊息');
      expect(newState.pendingInteraction, isNull, reason: '切換設備時必須清理舊機器之待審批項，避免錯批到新機器');
    });
  });
}
