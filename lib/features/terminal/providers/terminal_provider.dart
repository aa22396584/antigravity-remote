import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/terminal_stream.dart';
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
  static const int maxBufferChunks = 1000;
  StreamSubscription? _termSub;

  @override
  TerminalState build() {
    final remoteService = ref.watch(remoteControlServiceProvider);

    ref.onDispose(() {
      _termSub?.cancel();
    });

    _termSub = remoteService.terminalStream.listen((chunk) {
      final updated = [...state.chunks, chunk];
      final trimmed = updated.length > maxBufferChunks
          ? updated.sublist(updated.length - maxBufferChunks)
          : updated;
      state = state.copyWith(
        chunks: trimmed,
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
    final updated = [...state.chunks, chunk];
    final trimmed = updated.length > maxBufferChunks
        ? updated.sublist(updated.length - maxBufferChunks)
        : updated;
    state = state.copyWith(chunks: trimmed);

    final remoteService = ref.read(remoteControlServiceProvider);
    await remoteService.sendTerminalInput(input);
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
