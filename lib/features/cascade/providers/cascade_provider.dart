import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/cascade_message.dart';
import '../../../core/models/trajectory_step.dart';
import '../../../core/models/user_interaction.dart';
import '../../device/providers/device_provider.dart';

class CascadeState {
  final String activeCascadeId;
  final List<CascadeMessage> messages;
  final bool isStreaming;
  final UserInteractionRequest? pendingInteraction;
  final String? errorMessage;

  const CascadeState({
    this.activeCascadeId = 'cascade-main',
    this.messages = const [],
    this.isStreaming = false,
    this.pendingInteraction,
    this.errorMessage,
  });

  CascadeState copyWith({
    String? activeCascadeId,
    List<CascadeMessage>? messages,
    bool? isStreaming,
    UserInteractionRequest? pendingInteraction,
    bool clearPendingInteraction = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CascadeState(
      activeCascadeId: activeCascadeId ?? this.activeCascadeId,
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      pendingInteraction: clearPendingInteraction
          ? null
          : (pendingInteraction ?? this.pendingInteraction),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CascadeNotifier extends Notifier<CascadeState> {
  StreamSubscription? _msgSub;
  StreamSubscription? _interactSub;

  @override
  CascadeState build() {
    final remoteService = ref.watch(remoteControlServiceProvider);

    ref.onDispose(() {
      _msgSub?.cancel();
      _interactSub?.cancel();
    });

    _msgSub = remoteService.messageStream.listen(_upsertMessage);
    _interactSub = remoteService.interactionStream.listen((req) {
      state = state.copyWith(pendingInteraction: req);
    });

    // 切換或刪除裝置時，原子性清理畫面上的舊對話與待審批狀態，避免操作送到舊機器 (P0 #1)
    ref.listen(deviceProvider.select((s) => s.activeDevice?.instanceId), (
      prevId,
      nextId,
    ) {
      if (prevId != nextId) {
        clearConversation();
      }
    });

    final deviceState = ref.read(deviceProvider);
    final activeDevice = deviceState.activeDevice;

    CascadeMessage welcomeMsg;
    if (deviceState.isDemoMode) {
      welcomeMsg = CascadeMessage(
        id: 'msg-welcome',
        cascadeId: 'cascade-main',
        role: MessageRole.assistant,
        content:
            '### 🧪 Antigravity 遠端控制中樞已就緒 (展示模式 Demo Mode)\n\n'
            '目前處於離線展示環境，所有操作皆為本機模擬，不會向真實遠端電腦發送指令。\n'
            '您可在此體驗完整 Prompt 思考、指令審批與虛擬終端互動。',
        thinking: '展示環境已就緒。\n模擬本機 Agent 連線與審批互動。',
        thinkingDuration: const Duration(seconds: 1, milliseconds: 200),
        isThinking: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      );
    } else if (activeDevice == null) {
      welcomeMsg = CascadeMessage(
        id: 'msg-welcome',
        cascadeId: 'cascade-main',
        role: MessageRole.assistant,
        content:
            '### 🚀 Antigravity 遠端控制中樞\n\n'
            '尚未連線至遠端 Antigravity 實體。\n'
            '請在「裝置列表」中配對或選取欲連線控制的電腦。',
        thinking: '等待選擇遠端連線目標...',
        isThinking: false,
        timestamp: DateTime.now(),
      );
    } else {
      final latText = deviceState.currentLatencyMs != null
          ? '${deviceState.currentLatencyMs}ms'
          : '—';
      welcomeMsg = CascadeMessage(
        id: 'msg-welcome',
        cascadeId: 'cascade-main',
        role: MessageRole.assistant,
        content:
            '### 🚀 Antigravity 遠端控制中樞已就緒\n\n'
            '連線目標實體 ID: `${activeDevice.instanceId}`\n'
            '傳輸通道: ${deviceState.activeTransport.name.toUpperCase()} (實測延遲: $latText)\n\n'
            '您可以在此監控 Agent 執行、核准終端指令與引導編程。',
        thinking: '連線已就緒。\n目標實體: ${activeDevice.instanceId}\n等待指令輸入。',
        isThinking: false,
        timestamp: DateTime.now(),
      );
    }

    return CascadeState(messages: [welcomeMsg]);
  }

  void _upsertMessage(CascadeMessage msg) {
    final list = List<CascadeMessage>.from(state.messages);
    final idx = list.indexWhere((m) => m.id == msg.id);
    if (idx != -1) {
      list[idx] = msg;
    } else {
      list.add(msg);
    }
    state = state.copyWith(messages: list, isStreaming: msg.isStreaming);
  }

  /// 發送使用者訊息 / Prompt (包含交付狀態追蹤與錯誤保留 - Issue #19)
  Future<bool> sendPrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return false;

    final userMsgId = 'msg-user-${DateTime.now().millisecondsSinceEpoch}';
    final userMsg = CascadeMessage(
      id: userMsgId,
      cascadeId: state.activeCascadeId,
      role: MessageRole.user,
      content: trimmed,
      timestamp: DateTime.now(),
      deliveryStatus: MessageDeliveryStatus.sending,
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isStreaming: true,
      clearError: true,
    );

    try {
      final remoteService = ref.read(remoteControlServiceProvider);
      await remoteService.sendPrompt(
        cascadeId: state.activeCascadeId,
        prompt: trimmed,
      );

      _updateMessageDeliveryStatus(userMsgId, MessageDeliveryStatus.confirmed);
      return true;
    } catch (e) {
      _updateMessageDeliveryStatus(userMsgId, MessageDeliveryStatus.failed);
      state = state.copyWith(isStreaming: false, errorMessage: '發送訊息失敗: $e');
      return false;
    }
  }

  void _updateMessageDeliveryStatus(String id, MessageDeliveryStatus status) {
    final updated = state.messages.map((m) {
      if (m.id == id) {
        return m.copyWith(deliveryStatus: status);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  /// 重新發送失敗的使用者訊息 (Retry - Issue #19)
  Future<void> retrySendMessage(String messageId) async {
    final msg = state.messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => throw ArgumentError('未找到對應訊息: $messageId'),
    );

    _updateMessageDeliveryStatus(messageId, MessageDeliveryStatus.sending);
    state = state.copyWith(isStreaming: true, clearError: true);

    try {
      final remoteService = ref.read(remoteControlServiceProvider);
      await remoteService.sendPrompt(
        cascadeId: state.activeCascadeId,
        prompt: msg.content,
      );
      _updateMessageDeliveryStatus(messageId, MessageDeliveryStatus.confirmed);
    } catch (e) {
      _updateMessageDeliveryStatus(messageId, MessageDeliveryStatus.failed);
      state = state.copyWith(isStreaming: false, errorMessage: '重試發送失敗: $e');
    }
  }

  /// 中止當前 Cascade 任務 (Stop Task - Issue #25)
  Future<void> cancelActiveTask() async {
    try {
      final remoteService = ref.read(remoteControlServiceProvider);
      await remoteService.cancelTask(cascadeId: state.activeCascadeId);
      state = state.copyWith(isStreaming: false);
    } catch (e) {
      state = state.copyWith(errorMessage: '中止任務失敗: $e');
    }
  }

  final Set<String> _inFlightApprovals = {};

  /// 處理使用者授權審批 (核准 / 拒絕) (P0 #4: 必須等待遠端 RPC 返回成功確認)
  Future<void> handleApproval({
    required String interactionId,
    required bool approved,
    String? feedback,
  }) async {
    if (_inFlightApprovals.contains(interactionId)) {
      throw StateError('該審批請求正在提交中，請勿重複送出');
    }
    _inFlightApprovals.add(interactionId);

    final remoteService = ref.read(remoteControlServiceProvider);

    try {
      // 1. 等待遠端確認 RPC 成功 (200 OK)
      await remoteService.handleApproval(
        interactionId: interactionId,
        approved: approved,
        feedback: feedback,
      );

      // 2. 遠端成功確認後，方將該步驟標註為完成/拒絕並清空待審批狀態
      final updatedMessages = state.messages.map((m) {
        final updatedSteps = m.trajectorySteps.map((s) {
          if (s.interaction?.interactionId == interactionId) {
            final updatedReq = s.interaction!.copyWith(
              status: approved
                  ? InteractionStatus.approved
                  : InteractionStatus.rejected,
              userFeedback: feedback,
            );
            return s.copyWith(
              status: approved ? StepStatus.completed : StepStatus.rejected,
              interaction: updatedReq,
            );
          }
          return s;
        }).toList();
        return m.copyWith(trajectorySteps: updatedSteps);
      }).toList();

      state = state.copyWith(
        messages: updatedMessages,
        clearPendingInteraction:
            state.pendingInteraction?.interactionId == interactionId,
        clearError: true,
      );
    } catch (e) {
      // 3. 遠端返回錯誤或逾時：嚴禁清空待審批狀態，嚴禁標註步驟完成！
      state = state.copyWith(errorMessage: '審批提交失敗，遠端未確認執行: $e');
      rethrow;
    } finally {
      _inFlightApprovals.remove(interactionId);
    }
  }

  void clearConversation() {
    state = state.copyWith(messages: [], clearPendingInteraction: true);
  }

  void removeMessage(String messageId) {
    final updated = state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: updated);
  }

  void switchCascade(String cascadeId) {
    if (state.activeCascadeId == cascadeId) return;
    state = state.copyWith(activeCascadeId: cascadeId);
  }
}

final cascadeProvider = NotifierProvider<CascadeNotifier, CascadeState>(
  CascadeNotifier.new,
);
