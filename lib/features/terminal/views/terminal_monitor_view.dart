import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../device/providers/device_provider.dart';
import '../../device/widgets/transport_badge.dart';
import '../providers/terminal_provider.dart';
import '../widgets/terminal_console_card.dart';

class TerminalMonitorView extends ConsumerWidget {
  const TerminalMonitorView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminalState = ref.watch(terminalProvider);
    final terminalNotifier = ref.read(terminalProvider.notifier);
    final deviceState = ref.watch(deviceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('即時終端輸出 (Live Terminal)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Row(
              children: [
                TransportBadge(
                  transport: deviceState.activeTransport,
                  latencyMs: deviceState.currentLatencyMs,
                  showPing: true,
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: TerminalConsoleCard(
            chunks: terminalState.chunks,
            onSendInput: (input) => terminalNotifier.sendInput(input),
            onShortcut: (key) => terminalNotifier.sendShortcut(key),
            onClear: () => terminalNotifier.clear(),
          ),
        ),
      ),
    );
  }
}
