import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CyberCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool hasGlow;
  final Color? glowColor;

  const CyberCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 14,
    this.onTap,
    this.hasGlow = false,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderColor ?? CyberColors.cardBorder;
    final effectiveGlow = glowColor ?? CyberColors.cyanGlow;

    final content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? CyberColors.card,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorder, width: 1),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: effectiveGlow,
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ]
            : [
                const BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: CyberColors.cyanGlow,
          highlightColor: Colors.white10,
          child: content,
        ),
      );
    }

    return content;
  }
}
