import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/terminal_stream.dart';
import '../../../core/services/mock_antigravity_service.dart';
import '../../device/providers/device_provider.dart';

class TerminalState {
  final List<TerminalChunk> chunks;
  final bool isStreaming;

  const TerminalState({
    this.chunks = const [],
    this.isStreaming = false,
  });

  TerminalState copyWith({
    List<TerminalChunk>? chunks,
    bool? isStreaming,
  }) {
    return TerminalState(
      chunks: chunks ?? this.chunks,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class TerminalNotifier extends Notifier<TerminalState> {
  StreamSubscription? _mockSub;

  @override
  TerminalState build() {
    ref.onDispose(() {
      _mockSub?.cancel();
    });

    _mockSub = MockAntigravityService.instance.terminalStream.listen((chunk) {
      state = state.copyWith(
        chunks: [...state.chunks, chunk],
        isStreaming: true,
      );
    });

    return TerminalState(
      chunks: [
        TerminalChunk(
          text: 'Antigravity Remote Terminal Bridge v2.12.2 [Darwin arm64]\n'
              'Connected via TransportMultiplexer -> LanguageServerService (ConnectRPC)\n'
              'Ready for remote command execution and live monitoring.\n\n',
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  Future<void> sendInput(String input) async {
    if (input.isEmpty) return;

    final chunk = TerminalChunk(
      text: input.endsWith('\n') ? input : '$input\n',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(chunks: [...state.chunks, chunk]);

    final deviceState = ref.read(deviceProvider);
    if (!deviceState.isDemoMode) {
      final manager = ref.read(deviceProvider.notifier).transportManager;
      if (manager != null) {
        // 調用 SendTerminalInput
      }
    }
  }

  void sendShortcut(String key) {
    if (key == 'Ctrl+C') {
      sendInput('\x03');
    } else if (key == 'Enter') {
      sendInput('\n');
    } else if (key == 'Tab') {
      sendInput('\t');
    } else if (key == 'clear') {
      clear();
    }
  }

  void clear() {
    state = state.copyWith(chunks: []);
  }
}

final terminalProvider = NotifierProvider<TerminalNotifier, TerminalState>(TerminalNotifier.new);
