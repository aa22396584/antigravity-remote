import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/core/models/cascade_message.dart';
import 'package:antigravity_remote/core/models/terminal_stream.dart';
import 'package:antigravity_remote/core/models/trajectory_step.dart';
import 'package:antigravity_remote/core/models/user_interaction.dart';
import 'package:antigravity_remote/core/network/endpoints.dart';
import 'package:antigravity_remote/core/services/remote_control_service.dart';
import '../../test_harness/mock_transport_harness.dart';

void main() {
  group('RemoteControlService Real Test Harness Tests', () {
    test('Demo Mode sends prompt and emits user message', () async {
      final service = RemoteControlService(isDemoMode: true);
      addTearDown(service.dispose);

      final messages = <CascadeMessage>[];
      final sub = service.messageStream.listen(messages.add);
      addTearDown(sub.cancel);

      await service.sendPrompt(cascadeId: 'cascade-test', prompt: '執行單元測試');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(messages.isNotEmpty, isTrue);
      expect(messages.first.content, '執行單元測試');
      expect(messages.first.role, MessageRole.user);
    });

    test('Demo Mode sendTerminalInput does NOT duplicate user input (fixes Double Echo)', () async {
      final service = RemoteControlService(isDemoMode: true);
      addTearDown(service.dispose);

      final chunks = <TerminalChunk>[];
      final sub = service.terminalStream.listen(chunks.add);
      addTearDown(sub.cancel);

      // In demo mode, sendTerminalInput should NOT re-emit the user input directly
      await service.sendTerminalInput('pwd');
      await Future.delayed(const Duration(milliseconds: 200));

      // Terminal should receive simulated response, NOT a duplicate echo of 'pwd'
      expect(chunks.any((c) => c.text == 'pwd'), isFalse);
      expect(chunks.any((c) => c.text.contains('antigravity_remote')), isTrue);
    });

    test('Live Mode calls SendUserCascadeMessage and starts reactive stream', () async {
      final harness = MockTransportHarness();
      addTearDown(harness.dispose);

      final service = RemoteControlService(
        isDemoMode: false,
        transportManager: harness,
      );
      addTearDown(service.dispose);

      await service.sendPrompt(cascadeId: 'c-live-1', prompt: '開始即時對話');

      // Assert unary RPC was called with correct payload
      expect(harness.unaryCalls.length, 1);
      final call = harness.unaryCalls.first;
      expect(call.rpcPath, ApiEndpoints.sendUserCascadeMessage);
      expect(call.payloadJson['cascadeId'], 'c-live-1');
      expect(call.payloadJson['message']['text'], '開始即時對話');

      // Assert stream was started
      expect(harness.streamCalls.any((s) => s.rpcPath == ApiEndpoints.streamCascadeReactiveUpdates), isTrue);
    });

    test('Live Mode parses 5-byte framed binary stream thinking updates', () async {
      final harness = MockTransportHarness();
      addTearDown(harness.dispose);

      final service = RemoteControlService(
        isDemoMode: false,
        transportManager: harness,
      );
      addTearDown(service.dispose);

      final messages = <CascadeMessage>[];
      final sub = service.messageStream.listen(messages.add);
      addTearDown(sub.cancel);

      await service.sendPrompt(cascadeId: 'c-thinking', prompt: '分析系統');

      // Feed real 5-byte framed binary thinking packet
      harness.emitFramedCascadeJson({
        'thinking': '正在檢索工作區抽象語法樹 (AST)...',
        'is_thinking': true,
      });

      await Future.delayed(Duration.zero);

      expect(messages.isNotEmpty, isTrue);
      final lastMsg = messages.last;
      expect(lastMsg.thinking, '正在檢索工作區抽象語法樹 (AST)...');
      expect(lastMsg.isThinking, isTrue);

      // Feed thinking completion
      harness.emitFramedCascadeJson({
        'thinking': 'AST 分析完成，準備調用工具',
        'is_thinking': false,
      });

      await Future.delayed(Duration.zero);
      expect(messages.last.thinking, 'AST 分析完成，準備調用工具');
      expect(messages.last.isThinking, isFalse);
    });

    test('Live Mode parses 5-byte framed binary tool steps and snake_case properties', () async {
      final harness = MockTransportHarness();
      addTearDown(harness.dispose);

      final service = RemoteControlService(
        isDemoMode: false,
        transportManager: harness,
      );
      addTearDown(service.dispose);

      final messages = <CascadeMessage>[];
      final sub = service.messageStream.listen(messages.add);
      addTearDown(sub.cancel);

      await service.sendPrompt(cascadeId: 'c-step', prompt: '執行工具調用');

      // Feed real 5-byte framed binary step with snake_case keys
      harness.emitFramedCascadeJson({
        'trajectory_step': {
          'step_id': 'step-grep-100',
          'type': 'tool_call',
          'tool_name': 'grep_search',
          'summary': '搜尋 FrameAccumulator 實作',
          'description': '在 lib/ 目錄下檢索類別',
          'arguments': {'Query': 'class FrameAccumulator'},
          'output': 'Found 1 match in lib/core/network/webrtc_mesh_client.dart',
          'status': 'completed',
          'execution_duration_ms': 180,
        },
      });

      await Future.delayed(Duration.zero);

      final lastMsg = messages.last;
      expect(lastMsg.trajectorySteps.length, 1);
      final step = lastMsg.trajectorySteps.first;
      expect(step.stepId, 'step-grep-100');
      expect(step.toolName, 'grep_search');
      expect(step.summary, '搜尋 FrameAccumulator 實作');
      expect(step.status, StepStatus.completed);
      expect(step.output, contains('lib/core/network/webrtc_mesh_client.dart'));
      expect(step.executionDuration?.inMilliseconds, 180);
    });

    test('Live Mode parses 5-byte framed binary code diffs in file changes', () async {
      final harness = MockTransportHarness();
      addTearDown(harness.dispose);

      final service = RemoteControlService(
        isDemoMode: false,
        transportManager: harness,
      );
      addTearDown(service.dispose);

      final messages = <CascadeMessage>[];
      final sub = service.messageStream.listen(messages.add);
      addTearDown(sub.cancel);

      await service.sendPrompt(cascadeId: 'c-diff', prompt: '應用代碼變更');

      const expectedDiff = '@@ -20,3 +20,6 @@\n+ final accumulator = FrameAccumulator();\n+ accumulator.push(chunk);';

      harness.emitFramedCascadeJson({
        'step': {
          'stepId': 'step-diff-200',
          'type': 'fileChange',
          'toolName': 'replace_file_content',
          'summary': '加入 SCTP 分片緩衝',
          'code_diff': expectedDiff,
          'status': 'completed',
        },
      });

      await Future.delayed(Duration.zero);

      expect(messages.last.trajectorySteps.length, 1);
      final step = messages.last.trajectorySteps.first;
      expect(step.stepId, 'step-diff-200');
      expect(step.toolName, 'replace_file_content');
      expect(step.type, StepType.fileChange);
      expect(step.codeDiff, expectedDiff);
    });

    test('Live Mode parses UserInteraction permission request and executes handleApproval', () async {
      final harness = MockTransportHarness();
      addTearDown(harness.dispose);

      final service = RemoteControlService(
        isDemoMode: false,
        transportManager: harness,
      );
      addTearDown(service.dispose);

      final interactions = <UserInteractionRequest>[];
      final interactSub = service.interactionStream.listen(interactions.add);
      addTearDown(interactSub.cancel);

      await service.sendPrompt(cascadeId: 'c-interact', prompt: '需要授權');

      // Feed step with waitingUserInteraction requirement
      harness.emitFramedCascadeJson({
        'step': {
          'step_id': 'step-perm-300',
          'type': 'tool_call',
          'tool_name': 'run_command',
          'summary': '執行編譯與測試',
          'status': 'waiting_user_interaction',
          'interaction': {
            'interaction_id': 'interact-req-999',
            'type': 'ask_permission',
            'title': '請求授權執行指令',
            'description': 'Agent 請求執行 flutter test',
            'action_target': 'flutter test',
            'action_name': 'command',
            'status': 'pending',
          },
        },
      });

      await Future.delayed(Duration.zero);

      expect(interactions.length, 1);
      final req = interactions.first;
      expect(req.interactionId, 'interact-req-999');
      expect(req.actionTarget, 'flutter test');
      expect(req.title, '請求授權執行指令');
      expect(req.type, UserInteractionType.askPermission);

      // Now approve the request
      await service.handleApproval(
        interactionId: 'interact-req-999',
        approved: true,
        feedback: 'Approve flutter test execution',
      );

      expect(harness.unaryCalls.length, 2); // sendUserCascadeMessage + handleCascadeUserInteraction
      final approvalCall = harness.unaryCalls.last;
      expect(approvalCall.rpcPath, ApiEndpoints.handleCascadeUserInteraction);
      expect(approvalCall.payloadJson['interactionId'], 'interact-req-999');
      expect(approvalCall.payloadJson['decision'], 'DECISION_APPROVE');
      expect(approvalCall.payloadJson['userFeedback'], 'Approve flutter test execution');
    });

    test('Live Mode accumulates text streaming and finalizes on is_final', () async {
      final harness = MockTransportHarness();
      addTearDown(harness.dispose);

      final service = RemoteControlService(
        isDemoMode: false,
        transportManager: harness,
      );
      addTearDown(service.dispose);

      final messages = <CascadeMessage>[];
      final sub = service.messageStream.listen(messages.add);
      addTearDown(sub.cancel);

      await service.sendPrompt(cascadeId: 'c-text', prompt: '寫一篇文章');

      // Chunk 1
      harness.emitFramedCascadeJson({'content': '這是第 1 段內容。'});
      await Future.delayed(Duration.zero);
      expect(messages.last.content, '這是第 1 段內容。');
      expect(messages.last.isStreaming, isTrue);

      // Chunk 2
      harness.emitFramedCascadeJson({'content': '\n這是第 2 段內容。'});
      await Future.delayed(Duration.zero);
      expect(messages.last.content, '這是第 1 段內容。\n這是第 2 段內容。');

      // Final Chunk
      harness.emitFramedCascadeJson({'is_final': true});
      await Future.delayed(Duration.zero);
      expect(messages.last.isStreaming, isFalse);
    });

    test('Cascade and Terminal streams are isolated without cross-contamination', () async {
      final harness = MockTransportHarness();
      addTearDown(harness.dispose);

      final service = RemoteControlService(
        isDemoMode: false,
        transportManager: harness,
      );
      addTearDown(service.dispose);

      final messages = <CascadeMessage>[];
      final terminalChunks = <TerminalChunk>[];

      final msgSub = service.messageStream.listen(messages.add);
      final termSub = service.terminalStream.listen(terminalChunks.add);
      addTearDown(msgSub.cancel);
      addTearDown(termSub.cancel);

      await service.sendPrompt(cascadeId: 'c-isolate', prompt: '多工分流測試');

      // Emit Cascade update
      harness.emitFramedCascadeJson({'content': 'Chat Content'});

      // Emit Terminal output
      harness.emitTerminalText('00:02 +10: All tests passed!\n');

      await Future.delayed(Duration.zero);

      // Terminal output should only exist in terminalChunks
      expect(terminalChunks.length, 1);
      expect(terminalChunks.first.text, '00:02 +10: All tests passed!\n');

      // Cascade message should ONLY contain 'Chat Content' and NEVER be polluted by terminal text
      final lastMsg = messages.last;
      expect(lastMsg.content, 'Chat Content');
      expect(lastMsg.content.contains('All tests passed'), isFalse);
    });

    test('Live Mode handles stream error with user notification', () async {
      final harness = MockTransportHarness();
      addTearDown(harness.dispose);

      final service = RemoteControlService(
        isDemoMode: false,
        transportManager: harness,
      );
      addTearDown(service.dispose);

      final messages = <CascadeMessage>[];
      final sub = service.messageStream.listen(messages.add);
      addTearDown(sub.cancel);

      await service.sendPrompt(cascadeId: 'c-err', prompt: '測試連線中斷');

      harness.emitCascadeError('SCTP connection reset by peer');
      await Future.delayed(Duration.zero);

      expect(messages.isNotEmpty, isTrue);
      final lastMsg = messages.last;
      expect(lastMsg.isStreaming, isFalse);
      expect(lastMsg.content, contains('⚠️ 連線中斷'));
      expect(lastMsg.content, contains('SCTP connection reset by peer'));
    });
  });
}
