import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CyberButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final bool isOutlined;
  final bool isLoading;
  final double? width;
  final EdgeInsetsGeometry padding;

  const CyberButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.color,
    this.textColor,
    this.isOutlined = false,
    this.isLoading = false,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? CyberColors.cyan;
    final effectiveTextColor = textColor ?? (isOutlined ? effectiveColor : Colors.black);

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveTextColor),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: effectiveTextColor),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            color: effectiveTextColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );

    if (isOutlined) {
      return SizedBox(
        width: width,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            padding: padding,
            side: BorderSide(color: effectiveColor, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveColor,
          foregroundColor: effectiveTextColor,
          elevation: 0,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          shadowColor: effectiveColor.withOpacity(0.5),
        ),
        child: child,
      ),
    );
  }
}
