import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CodeDiffViewer extends StatelessWidget {
  final String diff;

  const CodeDiffViewer({
    super.key,
    required this.diff,
  });

  @override
  Widget build(BuildContext context) {
    final lines = diff.split('\n');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CyberColors.terminalBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CyberColors.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines) _buildDiffLine(line),
        ],
      ),
    );
  }

  Widget _buildDiffLine(String line) {
    Color textColor = CyberColors.textSecondary;
    Color? bgColor;

    if (line.startsWith('+') && !line.startsWith('+++')) {
      textColor = CyberColors.emerald;
      bgColor = CyberColors.emerald.withOpacity(0.12);
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      textColor = CyberColors.red;
      bgColor = CyberColors.red.withOpacity(0.12);
    } else if (line.startsWith('@@')) {
      textColor = CyberColors.cyan;
      bgColor = CyberColors.cyan.withOpacity(0.08);
    }

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Text(
        line,
        style: AppTheme.codeFont(
          color: textColor,
          fontSize: 11.5,
        ),
      ),
    );
  }
}
