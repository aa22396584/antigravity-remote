import 'dart:async';
import '../models/cascade_message.dart';
import '../models/instance_info.dart';
import '../models/terminal_stream.dart';
import '../models/trajectory_step.dart';
import '../models/user_interaction.dart';

class MockAntigravityService {
  static final MockAntigravityService instance = MockAntigravityService._();
  MockAntigravityService._();

  final _messageController = StreamController<CascadeMessage>.broadcast();
  final _terminalController = StreamController<TerminalChunk>.broadcast();
  final _interactionController = StreamController<UserInteractionRequest>.broadcast();

  Stream<CascadeMessage> get messageStream => _messageController.stream;
  Stream<TerminalChunk> get terminalStream => _terminalController.stream;
  Stream<UserInteractionRequest> get interactionStream => _interactionController.stream;

  List<InstanceInfo> getMockInstances() {
    return [
      InstanceInfo(
        instanceId: '2114863e-6436-4398-b26f-8672c1bd5e4b-v2',
        uuid: 'uuid-surge-macbook-pro-4',
        name: 'iml1sdemacbook-pro-4-local-deep-surge',
        version: '2.12.2',
        status: InstanceConnectionStatus.connected,
        transport: TransportType.p2p,
        latencyMs: 14,
        lastSeen: DateTime.now(),
        isDefault: true,
      ),
      InstanceInfo(
        instanceId: '7a9c1e42-18bc-4e20-9421-a08ef48d8102-v2',
        uuid: 'uuid-studio-workstation',
        name: 'CBStudio-MacStudio-M2Ultra',
        version: '2.12.2',
        status: InstanceConnectionStatus.connected,
        transport: TransportType.relay,
        latencyMs: 82,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
        isDefault: false,
      ),
    ];
  }

  /// 模擬發送 Prompt 並啟動 Agent 思考與工具執行長串流
  void simulateUserPrompt(String prompt, String cascadeId) {
    final userMsgId = 'msg-user-${DateTime.now().millisecondsSinceEpoch}';
    final assistantMsgId = 'msg-ai-${DateTime.now().millisecondsSinceEpoch}';

    // 1. 發布使用者訊息
    final userMsg = CascadeMessage(
      id: userMsgId,
      cascadeId: cascadeId,
      role: MessageRole.user,
      content: prompt,
      timestamp: DateTime.now(),
    );
    _messageController.add(userMsg);

    // 2. 模擬 Agent 開始思考
    var currentAiMsg = CascadeMessage(
      id: assistantMsgId,
      cascadeId: cascadeId,
      role: MessageRole.assistant,
      content: '',
      thinking: '正在連線至本機 LanguageServer (ConnectRPC)...\n分析請求上下文與工作區檔案...',
      isThinking: true,
      isStreaming: true,
      timestamp: DateTime.now(),
    );
    _messageController.add(currentAiMsg);

    // 思考串流微互動
    Timer(const Duration(milliseconds: 1200), () {
      currentAiMsg = currentAiMsg.copyWith(
        thinking: '正在連線至本機 LanguageServer (ConnectRPC)...\n'
            '分析請求上下文與工作區檔案...\n'
            '檢測到專案為 Flutter 跨平台專案，準備執行語法檢查與測試套件...',
      );
      _messageController.add(currentAiMsg);
    });

    // 3. 觸發步驟 1：檢索檔案
    Timer(const Duration(milliseconds: 2500), () {
      final step1 = TrajectoryStep(
        stepId: 'step-1',
        type: StepType.toolCall,
        toolName: 'find_by_name',
        summary: '搜尋測試與核心模型檔案',
        description: '查找 lib/core/models 與 test/ 目錄下的 Dart 檔案',
        arguments: {'Pattern': '*.dart', 'SearchDirectory': 'lib/core/models'},
        status: StepStatus.completed,
        output: 'Found 4 matching files:\n- lib/core/models/instance_info.dart\n- lib/core/models/user_interaction.dart\n- lib/core/models/trajectory_step.dart\n- lib/core/models/cascade_message.dart',
        timestamp: DateTime.now(),
        executionDuration: const Duration(milliseconds: 320),
      );

      currentAiMsg = currentAiMsg.copyWith(
        isThinking: false,
        thinkingDuration: const Duration(seconds: 2, milliseconds: 400),
        trajectorySteps: [step1],
      );
      _messageController.add(currentAiMsg);
    });

    // 4. 觸發步驟 2：請求執行指令 (需要使用者審批 WAITING_USER_INTERACTION)
    Timer(const Duration(milliseconds: 4000), () {
      final interactionReq = UserInteractionRequest(
        interactionId: 'interact-perm-flutter-test',
        type: UserInteractionType.askPermission,
        title: '請求授權執行終端指令',
        description: 'Agent 計劃在桌面端執行單元測試以驗證當前實作正確性。',
        actionTarget: 'flutter test test/core/services/qr_parser_test.dart',
        actionName: 'command',
        isDestructive: false,
        status: InteractionStatus.pending,
        requestedAt: DateTime.now(),
      );

      final step2 = TrajectoryStep(
        stepId: 'step-2',
        type: StepType.toolCall,
        toolName: 'run_command',
        summary: '執行單元測試',
        description: '執行 flutter test 驗證核心邏輯',
        arguments: {
          'CommandLine': 'flutter test test/core/services/qr_parser_test.dart',
          'Cwd': '/Users/iml1s/Documents/mine/antigravity_remote',
        },
        status: StepStatus.waitingUserInteraction,
        interaction: interactionReq,
        timestamp: DateTime.now(),
      );

      final steps = List<TrajectoryStep>.from(currentAiMsg.trajectorySteps)..add(step2);
      currentAiMsg = currentAiMsg.copyWith(
        trajectorySteps: steps,
      );
      _messageController.add(currentAiMsg);
      _interactionController.add(interactionReq);
    });
  }

  /// 使用者審批（Approve / Reject）回調
  void handleUserApproval({
    required String interactionId,
    required bool approved,
    String? feedback,
  }) {
    // 終端輸出模擬
    if (approved) {
      _terminalController.add(TerminalChunk(
        text: '\$ flutter test test/core/services/qr_parser_test.dart\n',
        timestamp: DateTime.now(),
      ));

      Timer(const Duration(milliseconds: 400), () {
        _terminalController.add(TerminalChunk(
          text: '00:01 +0: loading test/core/services/qr_parser_test.dart\n',
          timestamp: DateTime.now(),
        ));
      });

      Timer(const Duration(milliseconds: 900), () {
        _terminalController.add(TerminalChunk(
          text: '00:02 +1: QR code parser with Google AccountChooser URL\n'
              '00:02 +2: QR code parser with Antigravity schema\n'
              '00:02 +3: All tests passed!\n',
          timestamp: DateTime.now(),
        ));
      });

      // 步驟 3：完成代碼修改呈現
      Timer(const Duration(milliseconds: 1500), () {
        final step3 = TrajectoryStep(
          stepId: 'step-3',
          type: StepType.fileChange,
          toolName: 'replace_file_content',
          summary: '更新 DualTransportManager 配置',
          description: '優化 WebRTC P2P 與 Cloud Relay 的自適應切換閾值',
          arguments: {
            'TargetFile': 'lib/core/network/dual_transport_manager.dart',
          },
          codeDiff: '@@ -35,6 +35,8 @@\n+    // 自動優先選擇 P2P 高速通道\n+    if (meshClient?.isConnected == true) return meshClient;\n     return relayClient;',
          status: StepStatus.completed,
          output: 'Successfully applied code modification',
          timestamp: DateTime.now(),
          executionDuration: const Duration(milliseconds: 450),
        );

        final finalMsg = CascadeMessage(
          id: 'msg-final-${DateTime.now().millisecondsSinceEpoch}',
          cascadeId: 'cascade-default',
          role: MessageRole.assistant,
          content: '### ✅ 任務執行完成\n\n'
              '- **單元測試驗證**：所有 3 個測試已順利通過 (00:02)\n'
              '- **雙軌傳輸最佳化**：已成功提升 WebRTC P2P 連線權重，目前端到端延遲為 **14ms**\n'
              '- **桌面端狀態**：Antigravity LanguageServer 運作正常，隨時可接收後續控制指令。',
          thinking: '所有驗證已完成，產出繁體中文總結報告。',
          isThinking: false,
          isStreaming: false,
          trajectorySteps: [step3],
          timestamp: DateTime.now(),
        );

        _messageController.add(finalMsg);
      });
    } else {
      _terminalController.add(TerminalChunk(
        text: '⚠️ 指令執行已被使用者拒絕: ${feedback ?? "User rejected"}\n',
        isError: true,
        timestamp: DateTime.now(),
      ));

      final rejectMsg = CascadeMessage(
        id: 'msg-reject-${DateTime.now().millisecondsSinceEpoch}',
        cascadeId: 'cascade-default',
        role: MessageRole.assistant,
        content: '收到拒絕指令，已取消該步驟之執行。請問是否有其他需要微調之處？',
        isStreaming: false,
        timestamp: DateTime.now(),
      );
      _messageController.add(rejectMsg);
    }
  }

  /// 模擬使用者手動中止 / 取消當前任務 (Stop Task)
  void simulateCancelTask(String cascadeId) {
    _messageController.add(CascadeMessage(
      id: 'msg-cancel-${DateTime.now().millisecondsSinceEpoch}',
      cascadeId: cascadeId,
      role: MessageRole.assistant,
      content: '🛑 **任務已由使用者手動中止**\n\n遠端執行已取消，工作區保持當前狀態。',
      isStreaming: false,
      timestamp: DateTime.now(),
    ));
    _terminalController.add(TerminalChunk(
      text: '^C\n[任務已被使用者手動中止]\n',
      isError: true,
      timestamp: DateTime.now(),
    ));
  }

  void dispose() {
    _messageController.close();
    _terminalController.close();
    _interactionController.close();
  }
}
