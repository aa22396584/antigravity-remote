import 'package:flutter/material.dart';
import '../../../core/models/instance_info.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cyber_card.dart';
import 'transport_badge.dart';

class DeviceCard extends StatelessWidget {
  final InstanceInfo device;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;

  const DeviceCard({
    super.key,
    required this.device,
    required this.isSelected,
    required this.onSelect,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? CyberColors.cyan
        : CyberColors.subtleBorder;

    return CyberCard(
      onTap: onSelect,
      borderColor: borderColor,
      hasGlow: isSelected,
      glowColor: CyberColors.cyanGlow,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected
                      ? CyberColors.cyan.withOpacity(0.15)
                      : CyberColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? CyberColors.cyan : CyberColors.subtleBorder,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.laptop_mac,
                  size: 20,
                  color: isSelected ? CyberColors.cyan : CyberColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : CyberColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${device.instanceId}',
                      style: AppTheme.codeFont(
                        color: CyberColors.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: CyberColors.textMuted),
                  onPressed: onDelete,
                  splashRadius: 18,
                  tooltip: '解除綁定',
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: CyberColors.subtleBorder),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TransportBadge(
                transport: device.transport,
                latencyMs: device.latencyMs,
              ),
              Row(
                children: [
                  if (isSelected) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: CyberColors.cyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '目前控制中',
                        style: TextStyle(
                          color: CyberColors.cyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      '點擊切換',
                      style: TextStyle(
                        color: CyberColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
