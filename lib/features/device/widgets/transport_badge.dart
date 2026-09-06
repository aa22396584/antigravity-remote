import 'package:flutter/material.dart';
import '../../../core/models/instance_info.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/status_indicator.dart';

class TransportBadge extends StatelessWidget {
  final TransportType transport;
  final int? latencyMs;
  final bool showPing;
  final VoidCallback? onTap;

  const TransportBadge({
    super.key,
    required this.transport,
    this.latencyMs,
    this.showPing = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String label;
    IconData icon;

    switch (transport) {
      case TransportType.p2p:
        badgeColor = CyberColors.emerald;
        label = 'P2P WebRTC';
        icon = Icons.bolt;
        break;
      case TransportType.relay:
        badgeColor = CyberColors.cyan;
        label = 'Cloud Relay';
        icon = Icons.cloud_queue;
        break;
      case TransportType.offline:
        badgeColor = CyberColors.red;
        label = '離線 (Offline)';
        icon = Icons.link_off;
        break;
    }

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusIndicator(color: badgeColor, size: 7),
          const SizedBox(width: 6),
          Icon(icon, size: 13, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          if (showPing && latencyMs != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${latencyMs}ms',
                style: AppTheme.codeFont(
                  color: badgeColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: content,
      );
    }

    return content;
  }
}
