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

      final updated = dev.copyWith(
        latencyMs: 18,
        transport: TransportType.relay,
      );
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

    test(
      'TrajectoryStep fromJson handles snake_case keys and flexible enums',
      () {
        final json = {
          'step_id': 'step-snake-01',
          'type': 'tool_call',
          'tool_name': 'run_command',
          'summary': '執行編譯',
          'description': '編譯目標平台二進位檔',
          'args': {'cmd': 'flutter build'},
          'code_diff': '@@ -1 +1 @@\n+patched',
          'output': 'Build success',
          'status': 'waiting_user_interaction',
          'execution_duration_ms': 550,
        };

        final step = TrajectoryStep.fromJson(json);
        expect(step.stepId, 'step-snake-01');
        expect(step.type, StepType.toolCall);
        expect(step.toolName, 'run_command');
        expect(step.arguments['cmd'], 'flutter build');
        expect(step.codeDiff, '@@ -1 +1 @@\n+patched');
        expect(step.status, StepStatus.waitingUserInteraction);
        expect(step.executionDuration?.inMilliseconds, 550);
      },
    );

    test('UserInteractionRequest fromJson handles snake_case keys', () {
      final json = {
        'interaction_id': 'req-snake-02',
        'interaction_type': 'ask_permission',
        'request_title': '授權指令',
        'description': '請求終端權限',
        'action_target': 'rm -rf /tmp/cache',
        'action_name': 'command',
        'is_multi_select': true,
        'is_destructive': true,
        'interaction_status': 'pending',
        'user_feedback': '無反饋',
      };

      final req = UserInteractionRequest.fromJson(json);
      expect(req.interactionId, 'req-snake-02');
      expect(req.type, UserInteractionType.askPermission);
      expect(req.title, '授權指令');
      expect(req.actionTarget, 'rm -rf /tmp/cache');
      expect(req.isMultiSelect, isTrue);
      expect(req.isDestructive, isTrue);
      expect(req.status, InteractionStatus.pending);
      expect(req.userFeedback, '無反饋');
    });

    test('CascadeMessage fromJson handles snake_case keys', () {
      final json = {
        'id': 'msg-snake-03',
        'cascade_id': 'casc-snake-888',
        'role': 'assistant',
        'text': '已完成解析',
        'thinking': '思考中...',
        'is_thinking': true,
        'thinking_duration_ms': 1200,
        'is_streaming': true,
      };

      final msg = CascadeMessage.fromJson(json);
      expect(msg.id, 'msg-snake-03');
      expect(msg.cascadeId, 'casc-snake-888');
      expect(msg.content, '已完成解析');
      expect(msg.thinking, '思考中...');
      expect(msg.isThinking, isTrue);
      expect(msg.thinkingDuration?.inMilliseconds, 1200);
      expect(msg.isStreaming, isTrue);
    });

    test(
      'TrajectoryStep fromJson accurately handles gRPC uppercase prefixed enums and untyped maps',
      () {
        final json = {
          'step_id': 'grpc-step-1',
          'type': 'STEP_TYPE_FILE_CHANGE',
          'status': 'STEP_STATUS_WAITING_USER_INTERACTION',
          'arguments': <dynamic, dynamic>{'path': 'lib/main.dart', 'lines': 42},
        };

        final step = TrajectoryStep.fromJson(json);
        expect(step.stepId, 'grpc-step-1');
        expect(step.type, StepType.fileChange);
        expect(step.status, StepStatus.waitingUserInteraction);
        expect(step.arguments['path'], 'lib/main.dart');
        expect(step.arguments['lines'], 42);
      },
    );

    test(
      'UserInteractionRequest fromJson accurately handles gRPC uppercase prefixed enums and int/str bools',
      () {
        final json = {
          'interaction_id': 'grpc-req-2',
          'interaction_type': 'USER_INTERACTION_TYPE_ASK_QUESTION',
          'interaction_status': 'INTERACTION_STATUS_APPROVED',
          'is_multi_select': 1,
          'is_destructive': 'true',
        };

        final req = UserInteractionRequest.fromJson(json);
        expect(req.interactionId, 'grpc-req-2');
        expect(req.type, UserInteractionType.askQuestion);
        expect(req.status, InteractionStatus.approved);
        expect(req.isMultiSelect, isTrue);
        expect(req.isDestructive, isTrue);
      },
    );
  });
}
