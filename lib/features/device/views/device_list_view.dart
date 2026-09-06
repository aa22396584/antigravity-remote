import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/qr_parser_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cyber_button.dart';
import '../../../shared/widgets/cyber_card.dart';
import '../../cascade/providers/cascade_provider.dart';
import '../providers/device_provider.dart';
import '../widgets/device_card.dart';
import '../widgets/transport_badge.dart';
import 'connection_settings_view.dart';
import 'qr_scanner_view.dart';

class DeviceListView extends ConsumerWidget {
  final VoidCallback onOpenChat;

  const DeviceListView({
    super.key,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceState = ref.watch(deviceProvider);
    final deviceNotifier = ref.read(deviceProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CyberColors.cyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CyberColors.cyan.withOpacity(0.5)),
              ),
              child: const Icon(Icons.hub_outlined, color: CyberColors.cyan, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Antigravity 控制台'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: CyberColors.textSecondary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConnectionSettingsView()),
              );
            },
            tooltip: '雲端與連線設定',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Active Device Hero Card
          if (deviceState.activeDevice != null) ...[
            CyberCard(
              borderColor: CyberColors.cyan,
              hasGlow: true,
              glowColor: CyberColors.cyanGlow,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '目前連線設備',
                        style: TextStyle(
                          fontSize: 12,
                          color: CyberColors.cyan,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      TransportBadge(
                        transport: deviceState.activeTransport,
                        latencyMs: deviceState.currentLatencyMs,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    deviceState.activeDevice!.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Instance UUID: ${deviceState.activeDevice!.instanceId}',
                    style: AppTheme.codeFont(
                      color: CyberColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CyberButton(
                          text: '進入 Agent 遠端工作區',
                          icon: Icons.chat_bubble_outline,
                          onPressed: onOpenChat,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 2. Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '已配對設備清單',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: CyberColors.textPrimary,
                ),
              ),
              CyberButton(
                text: '掃描 QR 配對',
                icon: Icons.qr_code_scanner,
                isOutlined: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                onPressed: () async {
                  final result = await Navigator.of(context).push<ParsedRemoteTarget>(
                    MaterialPageRoute(builder: (_) => const QrScannerView()),
                  );
                  if (result != null && context.mounted) {
                    await _handleScanResult(context, ref, result);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Devices List
          if (deviceState.devices.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Icon(Icons.devices_other, size: 48, color: CyberColors.textMuted),
                    const SizedBox(height: 12),
                    const Text(
                      '尚未配對任何 Antigravity 桌面端',
                      style: TextStyle(color: CyberColors.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    CyberButton(
                      text: '立即掃碼配對',
                      icon: Icons.qr_code_scanner,
                      onPressed: () async {
                        final result = await Navigator.of(context).push<ParsedRemoteTarget>(
                          MaterialPageRoute(builder: (_) => const QrScannerView()),
                        );
                        if (result != null && context.mounted) {
                          await _handleScanResult(context, ref, result);
                        }
                      },
                    ),
                  ],
                ),
              ),
            )
          else
            for (final dev in deviceState.devices)
              DeviceCard(
                device: dev,
                isSelected: dev.instanceId == deviceState.activeDevice?.instanceId,
                onSelect: () => deviceNotifier.selectDevice(dev),
                onDelete: () => deviceNotifier.removeDevice(dev.instanceId),
              ),

          const SizedBox(height: 20),

          // 4. Quick Help Card
          CyberCard(
            backgroundColor: CyberColors.surfaceElevated.withOpacity(0.5),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: CyberColors.cyan, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '如何在 Antigravity 開啟配對碼？\n'
                    '打開 Antigravity 編輯器 -> Settings -> 搜尋「Remote Control」-> 啟用「Enable Remote Control」即可顯示 QR Code。',
                    style: TextStyle(
                      color: CyberColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleScanResult(
    BuildContext context,
    WidgetRef ref,
    ParsedRemoteTarget result,
  ) async {
    final deviceNotifier = ref.read(deviceProvider.notifier);
    await deviceNotifier.addDevice(
      instanceId: result.instanceId,
      name: result.email != null ? 'Antigravity (${result.email})' : null,
      hostname: result.hostname,
    );
    if (result.cascadeId != null) {
      ref.read(cascadeProvider.notifier).switchCascade(result.cascadeId!);
    }
    if (context.mounted) {
      final shortId = result.instanceId.length > 12
          ? '${result.instanceId.substring(0, 12)}...'
          : result.instanceId;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: CyberColors.emerald, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('成功配對並切換設備: $shortId'),
              ),
            ],
          ),
          backgroundColor: CyberColors.surfaceElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: CyberColors.emerald),
          ),
        ),
      );
      onOpenChat();
    }
  }
}
