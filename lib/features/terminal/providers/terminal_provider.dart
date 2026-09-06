import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/terminal_stream.dart';
import '../../device/providers/device_provider.dart';

enum TerminalDisplayMode {
  log('日誌輸出模式 (Log Stream)'),
  pty('交互式終端模式 (PTY Shell)');

  final String label;
  const TerminalDisplayMode(this.label);
}

class TerminalState {
  final List<TerminalChunk> chunks;
  final bool isStreaming;
  final TerminalDisplayMode mode;
  final bool isTrimmed;

  const TerminalState({
    this.chunks = const [],
    this.isStreaming = false,
    this.mode = TerminalDisplayMode.log,
    this.isTrimmed = false,
  });

  TerminalState copyWith({
    List<TerminalChunk>? chunks,
    bool? isStreaming,
    TerminalDisplayMode? mode,
    bool? isTrimmed,
  }) {
    return TerminalState(
      chunks: chunks ?? this.chunks,
      isStreaming: isStreaming ?? this.isStreaming,
      mode: mode ?? this.mode,
      isTrimmed: isTrimmed ?? this.isTrimmed,
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
      _appendChunk(chunk);
    });

    // 切換或刪除裝置時，原子性清理終端緩衝，避免舊機器輸出混淆 (P0 #1)
    ref.listen(deviceProvider.select((s) => s.activeDevice?.instanceId), (prevId, nextId) {
      if (prevId != nextId) {
        clear();
      }
    });

    final deviceState = ref.read(deviceProvider);
    final activeDevice = deviceState.activeDevice;

    String initialBanner;
    if (deviceState.isDemoMode) {
      initialBanner = 'Antigravity Remote Terminal Bridge [Demo Mode]\n'
          '離線展示模式：模擬終端環境已就緒。\n\n';
    } else if (activeDevice == null) {
      initialBanner = 'Antigravity Remote Terminal Bridge\n'
          '目前未連線至任何遠端實體。請至控制台選取或配對裝置。\n\n';
    } else {
      initialBanner = 'Antigravity Remote Terminal Bridge\n'
          '連線目標: ${activeDevice.name} (${activeDevice.instanceId})\n'
          '傳輸通道: ${deviceState.activeTransport.name.toUpperCase()}\n\n';
    }

    return TerminalState(
      chunks: [
        TerminalChunk(
          text: initialBanner,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  void _appendChunk(TerminalChunk chunk) {
    final updated = [...state.chunks, chunk];
    if (updated.length > maxBufferChunks) {
      final sublist = updated.sublist(updated.length - maxBufferChunks);
      // 在頂部加入截斷省略標籤，告知使用者歷史已被限制 (Issue #24)
      if (sublist.isNotEmpty && !sublist.first.isSystem) {
        sublist[0] = TerminalChunk(
          text: '[... 較舊輸出已依緩衝上限自動省略 ...]\n',
          isSystem: true,
          timestamp: DateTime.now(),
        );
      }
      state = state.copyWith(
        chunks: sublist,
        isStreaming: true,
        isTrimmed: true,
      );
    } else {
      state = state.copyWith(
        chunks: updated,
        isStreaming: true,
      );
    }
  }

  /// 發送終端行指令 (附加換行符)
  Future<bool> sendInput(String input) async {
    if (input.isEmpty) return false;

    final wireInput = input.endsWith('\n') ? input : '$input\n';
    final chunk = TerminalChunk(
      text: wireInput,
      timestamp: DateTime.now(),
    );
    _appendChunk(chunk);

    try {
      final remoteService = ref.read(remoteControlServiceProvider);
      await remoteService.sendTerminalInput(wireInput);
      return true;
    } catch (e) {
      final errChunk = TerminalChunk(
        text: '\n[錯誤] 終端指令發送失敗: $e\n',
        isError: true,
        timestamp: DateTime.now(),
      );
      _appendChunk(errChunk);
      return false;
    }
  }

  /// 發送原始控制位元組 (例如 Ctrl+C / Tab，不自動附加換行符 - Issue #23)
  Future<bool> sendRaw(String rawBytes, {String? displayEcho}) async {
    if (rawBytes.isEmpty) return false;

    if (displayEcho != null && displayEcho.isNotEmpty) {
      final chunk = TerminalChunk(
        text: displayEcho,
        timestamp: DateTime.now(),
      );
      _appendChunk(chunk);
    }

    try {
      final remoteService = ref.read(remoteControlServiceProvider);
      await remoteService.sendTerminalInput(rawBytes);
      return true;
    } catch (e) {
      final errChunk = TerminalChunk(
        text: '\n[錯誤] 終端按鍵發送失敗: $e\n',
        isError: true,
        timestamp: DateTime.now(),
      );
      _appendChunk(errChunk);
      return false;
    }
  }

  /// 快捷鍵操作 (支援 await 與正確控制語義 - Issue #23)
  Future<void> sendShortcut(String key) async {
    if (key == 'Ctrl+C') {
      // 發送 SIGINT (\x03)，不附帶額外換行符
      await sendRaw('\x03', displayEcho: '^C\x03\n');
    } else if (key == 'Ctrl+D') {
      // 發送 EOF (\x04)
      await sendRaw('\x04', displayEcho: '^D\n');
    } else if (key == 'Esc') {
      // 發送 Escape (\x1b)
      await sendRaw('\x1b');
    } else if (key == 'Enter') {
      await sendRaw('\n', displayEcho: '\n');
    } else if (key == 'Tab') {
      await sendRaw('\t');
    } else if (key == 'clear') {
      clear();
    }
  }

  /// 清空本機終端畫面顯示
  void clear() {
    state = state.copyWith(chunks: []);
  }

  /// 切換顯示模式 (PTY vs 日誌監控)
  void setDisplayMode(TerminalDisplayMode mode) {
    state = state.copyWith(mode: mode);
  }
}

final terminalProvider = NotifierProvider<TerminalNotifier, TerminalState>(TerminalNotifier.new);
