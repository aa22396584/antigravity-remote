import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../models/cascade_message.dart';
import '../models/terminal_stream.dart';
import '../models/trajectory_step.dart';
import '../models/user_interaction.dart';
import '../network/dual_transport_manager.dart';
import '../network/endpoints.dart';
import 'mock_antigravity_service.dart';

/// 遠端控制中樞業務服務
/// 負責調度 Mock (離線展示) 與 DualTransportManager (線上真實連線)
class RemoteControlService {
  bool _isDemoMode = true;
  DualTransportManager? _transportManager;

  final _messageController = StreamController<CascadeMessage>.broadcast();
  final _interactionController = StreamController<UserInteractionRequest>.broadcast();
  final _terminalController = StreamController<TerminalChunk>.broadcast();

  StreamSubscription? _mockMsgSub;
  StreamSubscription? _mockInteractSub;
  StreamSubscription? _mockTermSub;

  StreamSubscription? _liveCascadeSub;
  StreamSubscription? _liveTerminalSub;

  // 當前進行中訊息狀態快取
  CascadeMessage? _currentLiveAiMessage;

  RemoteControlService({
    bool isDemoMode = true,
    DualTransportManager? transportManager,
  })  : _isDemoMode = isDemoMode,
        _transportManager = transportManager {
    _initListeners();
  }

  Stream<CascadeMessage> get messageStream => _messageController.stream;
  Stream<UserInteractionRequest> get interactionStream => _interactionController.stream;
  Stream<TerminalChunk> get terminalStream => _terminalController.stream;

  bool get isDemoMode => _isDemoMode;

  /// 完全重置當前裝置的連線工作階段，取消在途串流並清空暫態快取 (P0 #1)
  void resetDeviceSession() {
    _liveCascadeSub?.cancel();
    _liveCascadeSub = null;
    _liveTerminalSub?.cancel();
    _liveTerminalSub = null;
    _currentLiveAiMessage = null;
  }

  void updateConfiguration({
    required bool isDemoMode,
    DualTransportManager? transportManager,
  }) {
    resetDeviceSession();
    _isDemoMode = isDemoMode;
    _transportManager = transportManager;
    _initListeners();
  }

  void _initListeners() {
    // 釋放既有訂閱
    _mockMsgSub?.cancel();
    _mockInteractSub?.cancel();
    _mockTermSub?.cancel();
    _liveCascadeSub?.cancel();
    _liveTerminalSub?.cancel();

    if (_isDemoMode) {
      _mockMsgSub = MockAntigravityService.instance.messageStream.listen(
        _messageController.add,
      );
      _mockInteractSub = MockAntigravityService.instance.interactionStream.listen(
        _interactionController.add,
      );
      _mockTermSub = MockAntigravityService.instance.terminalStream.listen(
        _terminalController.add,
      );
    } else if (_transportManager != null) {
      _startLiveTerminalStream();
    }
  }

  /// 發送使用者訊息 / Prompt 至本機 LanguageServer
  Future<void> sendPrompt({
    required String cascadeId,
    required String prompt,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;

    if (_isDemoMode) {
      MockAntigravityService.instance.simulateUserPrompt(trimmed, cascadeId);
      return;
    }

    if (_transportManager == null) {
      throw StateError('尚未建立傳輸連線');
    }

    // 1. 組裝發送請求
    final reqPayload = jsonEncode({
      'cascadeId': cascadeId,
      'message': {
        'role': 'MESSAGE_ROLE_USER',
        'text': trimmed,
      },
    });

    // 2. 透過雙軌自適應調度發送
    await _transportManager!.callUnary(
      ApiEndpoints.sendUserCascadeMessage,
      Uint8List.fromList(utf8.encode(reqPayload)),
    );

    // 3. 確保即時響應串流 (StreamCascadeReactiveUpdates) 已連線
    _ensureLiveCascadeStream(cascadeId);
  }

  /// 確保正在監聽桌面端之 ReactiveUpdates 串流
  void _ensureLiveCascadeStream(String cascadeId) {
    _liveCascadeSub?.cancel();

    final reqPayload = jsonEncode({'cascadeId': cascadeId});
    final stream = _transportManager!.callStream(
      ApiEndpoints.streamCascadeReactiveUpdates,
      Uint8List.fromList(utf8.encode(reqPayload)),
    );

    _currentLiveAiMessage = CascadeMessage(
      id: 'msg-live-${DateTime.now().millisecondsSinceEpoch}',
      cascadeId: cascadeId,
      role: MessageRole.assistant,
      content: '',
      thinking: '正在接收桌面端即時回傳...',
      isThinking: true,
      isStreaming: true,
      timestamp: DateTime.now(),
    );
    _messageController.add(_currentLiveAiMessage!);

    _liveCascadeSub = stream.listen(
      (data) => _handleLiveCascadeChunk(data, cascadeId),
      onError: (err) {
        _currentLiveAiMessage = _currentLiveAiMessage?.copyWith(
          isStreaming: false,
          isThinking: false,
          content: '${_currentLiveAiMessage?.content ?? ""}\n\n⚠️ 連線中斷: $err',
        );
        if (_currentLiveAiMessage != null) {
          _messageController.add(_currentLiveAiMessage!);
        }
      },
      onDone: () {
        if (_currentLiveAiMessage != null) {
          _currentLiveAiMessage = _currentLiveAiMessage!.copyWith(
            isStreaming: false,
            isThinking: false,
          );
          _messageController.add(_currentLiveAiMessage!);
        }
      },
    );
  }

  /// 解析來自桌面端之 ReactiveUpdate 二進位/JSON 封包
  void _handleLiveCascadeChunk(Uint8List rawBytes, String cascadeId) {
    if (rawBytes.isEmpty) return;

    // 若有 5-byte 分幀前綴，剔除頭部（相容 0x00..0x0F 頻道多工旗標）
    Uint8List payload = rawBytes;
    if (rawBytes.length >= 5 && rawBytes[0] <= 0x0F) {
      final len = (rawBytes[1] << 24) |
          (rawBytes[2] << 16) |
          (rawBytes[3] << 8) |
          rawBytes[4];
      if (len >= 0 && rawBytes.length >= 5 + len) {
        payload = rawBytes.sublist(5, 5 + len);
      }
    }

    try {
      final text = utf8.decode(payload);
      final json = jsonDecode(text) as Map<String, dynamic>;

      _currentLiveAiMessage ??= CascadeMessage(
        id: 'msg-live-${DateTime.now().millisecondsSinceEpoch}',
        cascadeId: cascadeId,
        role: MessageRole.assistant,
        content: '',
        timestamp: DateTime.now(),
      );

      var msg = _currentLiveAiMessage!;

      // 1. 思考思維更新
      if (json['thinking'] != null) {
        final thinkingText = json['thinking'].toString();
        msg = msg.copyWith(
          thinking: thinkingText,
          isThinking: json['is_thinking'] as bool? ?? true,
        );
      }

      // 2. 步驟更新
      if (json['step'] != null || json['trajectory_step'] != null) {
        final stepMap = (json['step'] ?? json['trajectory_step']) as Map<String, dynamic>;
        final step = TrajectoryStep.fromJson(stepMap);
        final steps = List<TrajectoryStep>.from(msg.trajectorySteps);
        final idx = steps.indexWhere((s) => s.stepId == step.stepId);
        if (idx != -1) {
          steps[idx] = step;
        } else {
          steps.add(step);
        }
        msg = msg.copyWith(trajectorySteps: steps);

        // 若需要審批
        if (step.interaction != null && step.status == StepStatus.waitingUserInteraction) {
          _interactionController.add(step.interaction!);
        }
      }

      // 3. 獨立使用者互動審批請求
      if (json['interaction'] != null) {
        final interactMap = json['interaction'] as Map<String, dynamic>;
        final req = UserInteractionRequest.fromJson(interactMap);
        _interactionController.add(req);
      }

      // 4. 文字內容累積
      if (json['content'] != null || json['text'] != null) {
        final append = (json['content'] ?? json['text']).toString();
        msg = msg.copyWith(
          content: msg.content.isEmpty ? append : '${msg.content}$append',
          isThinking: false,
        );
      }

      // 5. 串流完成標記
      if (json['is_final'] == true || json['done'] == true) {
        msg = msg.copyWith(isStreaming: false, isThinking: false);
      }

      _currentLiveAiMessage = msg;
      _messageController.add(msg);
    } catch (_) {
      // 若為純字串串流
      final text = utf8.decode(payload, allowMalformed: true);
      if (_currentLiveAiMessage != null && text.isNotEmpty) {
        _currentLiveAiMessage = _currentLiveAiMessage!.copyWith(
          content: '${_currentLiveAiMessage!.content}$text',
        );
        _messageController.add(_currentLiveAiMessage!);
      }
    }
  }

  /// 處理指令與權限審批 (Approve / Reject)
  Future<void> handleApproval({
    required String interactionId,
    required bool approved,
    String? feedback,
  }) async {
    if (_isDemoMode) {
      MockAntigravityService.instance.handleUserApproval(
        interactionId: interactionId,
        approved: approved,
        feedback: feedback,
      );
      return;
    }

    if (_transportManager == null) {
      throw StateError('尚未建立傳輸連線');
    }

    final reqPayload = jsonEncode({
      'interactionId': interactionId,
      'decision': approved ? 'DECISION_APPROVE' : 'DECISION_REJECT',
      'userFeedback': feedback ?? '',
    });

    await _transportManager!.callUnary(
      ApiEndpoints.handleCascadeUserInteraction,
      Uint8List.fromList(utf8.encode(reqPayload)),
    );
  }

  /// 發送終端輸入
  Future<void> sendTerminalInput(String input) async {
    if (_isDemoMode) {
      // 解決 Demo 模式下的「雙重回顯（Double Echo）」Bug：
      // TerminalNotifier 在 UI 端已進行本地輸入回顯 (Local Echo)，
      // 在此僅模擬終端命令的回應輸出，絕不重複回顯使用者的原始輸入字串
      final trimmed = input.trim();
      if (trimmed.isNotEmpty && trimmed != '\x03' && trimmed != '\n' && trimmed != '\t') {
        _simulateDemoTerminalResponse(trimmed);
      }
      return;
    }

    if (_transportManager == null) {
      throw StateError('尚未建立傳輸連線');
    }

    final reqPayload = jsonEncode({'input': input});
    await _transportManager!.callUnary(
      ApiEndpoints.sendTerminalInput,
      Uint8List.fromList(utf8.encode(reqPayload)),
    );
  }

  void _simulateDemoTerminalResponse(String cmd) {
    Timer(const Duration(milliseconds: 120), () {
      if (!_terminalController.isClosed) {
        String response;
        if (cmd == 'pwd') {
          response = '/Users/iml1s/Documents/mine/antigravity_remote\n';
        } else if (cmd == 'whoami') {
          response = 'iml1s (local engineer)\n';
        } else if (cmd == 'git status') {
          response = 'On branch main\nYour branch is up to date with \'origin/main\'.\nnothing to commit, working tree clean\n';
        } else if (cmd.startsWith('flutter test')) {
          response = '00:01 +3: All tests passed!\n';
        } else if (cmd == 'ls' || cmd == 'ls -la') {
          response = 'drwxr-xr-x  12 iml1s  staff   384 Mar  6 12:00 .\n'
              '-rw-r--r--   1 iml1s  staff  4169 Mar  6 12:00 pubspec.yaml\n'
              'drwxr-xr-x   8 iml1s  staff   256 Mar  6 12:00 lib\n'
              'drwxr-xr-x   6 iml1s  staff   192 Mar  6 12:00 test\n';
        } else {
          response = '[demo-sh] executed: $cmd\n';
        }
        _terminalController.add(TerminalChunk(
          text: response,
          timestamp: DateTime.now(),
        ));
      }
    });
  }

  /// 啟動真實終端輸出即時串流 (StreamTerminalOutput)
  void _startLiveTerminalStream() {
    _liveTerminalSub?.cancel();
    if (_transportManager == null) return;

    try {
      final stream = _transportManager!.callStream(
        ApiEndpoints.streamTerminalOutput,
        Uint8List(0),
      );

      _liveTerminalSub = stream.listen(
        (data) {
          Uint8List payload = data;
          if (data.length >= 5 && data[0] <= 0x0F) {
            final len = (data[1] << 24) |
                (data[2] << 16) |
                (data[3] << 8) |
                data[4];
            if (len >= 0 && data.length >= 5 + len) {
              payload = data.sublist(5, 5 + len);
            }
          }
          final text = utf8.decode(payload, allowMalformed: true);
          _terminalController.add(TerminalChunk(
            text: text,
            timestamp: DateTime.now(),
          ));
        },
        onError: (err) {
          _terminalController.add(TerminalChunk(
            text: '\n[連線日誌] 終端串流發生異常: $err\n',
            isError: true,
            timestamp: DateTime.now(),
          ));
        },
      );
    } catch (_) {}
  }

  void dispose() {
    _mockMsgSub?.cancel();
    _mockInteractSub?.cancel();
    _mockTermSub?.cancel();
    _liveCascadeSub?.cancel();
    _liveTerminalSub?.cancel();
    _messageController.close();
    _interactionController.close();
    _terminalController.close();
  }
}
