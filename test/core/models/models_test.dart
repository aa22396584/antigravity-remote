import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/core/models/cascade_message.dart';
import 'package:antigravity_remote/core/models/instance_info.dart';
import 'package:antigravity_remote/core/models/terminal_stream.dart';
import 'package:antigravity_remote/core/models/trajectory_step.dart';
import 'package:antigravity_remote/core/models/user_interaction.dart';

void main() {
  group('Core Models Tests', () {
    test('InstanceInfo JSON serialization & copyWith', () {
      final now = DateTime.now();
      final dev = InstanceInfo(
        instanceId: 'inst-1234',
        uuid: 'uuid-1234',
        name: 'MyMacBook',
        status: InstanceConnectionStatus.connected,
        transport: TransportType.p2p,
        latencyMs: 12,
        lastSeen: now,
      );

      final json = dev.toJson();
      final restored = InstanceInfo.fromJson(json);

      expect(restored.instanceId, 'inst-1234');
      expect(restored.uuid, 'uuid-1234');
      expect(restored.name, 'MyMacBook');
      expect(restored.status, InstanceConnectionStatus.connected);
      expect(restored.transport, TransportType.p2p);
      expect(restored.latencyMs, 12);

      final updated = dev.copyWith(latencyMs: 18, transport: TransportType.relay);
      expect(updated.latencyMs, 18);
      expect(updated.transport, TransportType.relay);
    });

    test('UserInteractionRequest serialization', () {
      final now = DateTime.now();
      final req = UserInteractionRequest(
        interactionId: 'req-99',
        type: UserInteractionType.askPermission,
        title: '請求指令授權',
        description: '執行測試腳本',
        actionTarget: 'flutter test',
        actionName: 'command',
        isDestructive: false,
        status: InteractionStatus.pending,
        requestedAt: now,
      );

      final json = req.toJson();
      final restored = UserInteractionRequest.fromJson(json);

      expect(restored.interactionId, 'req-99');
      expect(restored.title, '請求指令授權');
      expect(restored.actionTarget, 'flutter test');
      expect(restored.status, InteractionStatus.pending);

      final approved = req.copyWith(
        status: InteractionStatus.approved,
        userFeedback: '核准執行',
      );
      expect(approved.status, InteractionStatus.approved);
      expect(approved.userFeedback, '核准執行');
    });

    test('TrajectoryStep serialization with diff and output', () {
      final now = DateTime.now();
      final step = TrajectoryStep(
        stepId: 'step-01',
        type: StepType.fileChange,
        toolName: 'replace_file_content',
        summary: '更新配置',
        arguments: {'TargetFile': 'lib/app.dart'},
        codeDiff: '@@ -1,3 +1,3 @@\n-old\n+new',
        output: 'Success',
        status: StepStatus.completed,
        timestamp: now,
        executionDuration: const Duration(milliseconds: 350),
      );

      final json = step.toJson();
      final restored = TrajectoryStep.fromJson(json);

      expect(restored.stepId, 'step-01');
      expect(restored.toolName, 'replace_file_content');
      expect(restored.arguments['TargetFile'], 'lib/app.dart');
      expect(restored.codeDiff, contains('+new'));
      expect(restored.status, StepStatus.completed);
      expect(restored.executionDuration?.inMilliseconds, 350);
    });

    test('CascadeMessage serialization', () {
      final now = DateTime.now();
      final msg = CascadeMessage(
        id: 'msg-456',
        cascadeId: 'cascade-1',
        role: MessageRole.assistant,
        content: '任務已完成',
        thinking: '正在分析中...',
        isThinking: false,
        thinkingDuration: const Duration(seconds: 2),
        timestamp: now,
      );

      final json = msg.toJson();
      final restored = CascadeMessage.fromJson(json);

      expect(restored.id, 'msg-456');
      expect(restored.cascadeId, 'cascade-1');
      expect(restored.role, MessageRole.assistant);
      expect(restored.content, '任務已完成');
      expect(restored.thinking, '正在分析中...');
      expect(restored.thinkingDuration?.inSeconds, 2);
    });

    test('TerminalChunk serialization', () {
      final now = DateTime.now();
      final chunk = TerminalChunk(
        text: 'flutter test passed!\n',
        isError: false,
        timestamp: now,
      );

      final json = chunk.toJson();
      final restored = TerminalChunk.fromJson(json);

      expect(restored.text, 'flutter test passed!\n');
      expect(restored.isError, isFalse);
    });
  });
}
