import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cyber_card.dart';

class ThinkingCard extends StatefulWidget {
  final String thinking;
  final bool isThinking;
  final Duration? duration;

  const ThinkingCard({
    super.key,
    required this.thinking,
    this.isThinking = false,
    this.duration,
  });

  @override
  State<ThinkingCard> createState() => _ThinkingCardState();
}

class _ThinkingCardState extends State<ThinkingCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isThinking; // 思考中預設展開

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isThinking) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ThinkingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isThinking != oldWidget.isThinking) {
      if (widget.isThinking) {
        _pulseController.repeat(reverse: true);
        setState(() => _isExpanded = true);
      } else {
        _pulseController.stop();
        _pulseController.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.thinking.isEmpty && !widget.isThinking) {
      return const SizedBox.shrink();
    }

    String headerTitle;
    if (widget.isThinking) {
      headerTitle = 'Agent 正在思考中...';
    } else if (widget.duration != null) {
      final sec = (widget.duration!.inMilliseconds / 1000).toStringAsFixed(1);
      headerTitle = '思考完畢 (耗時 ${sec}s)';
    } else {
      headerTitle = '思考過程';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: CyberCard(
        borderColor: CyberColors.violet.withOpacity(0.35),
        backgroundColor: CyberColors.surface.withOpacity(0.8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CyberColors.violet.withOpacity(
                            widget.isThinking ? 0.25 * _pulseAnimation.value : 0.15,
                          ),
                          boxShadow: widget.isThinking
                              ? [
                                  BoxShadow(
                                    color: CyberColors.violet.withOpacity(0.5 * _pulseAnimation.value),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: const Icon(
                          Icons.psychology,
                          size: 16,
                          color: CyberColors.violet,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    headerTitle,
                    style: const TextStyle(
                      color: CyberColors.violet,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: CyberColors.textMuted,
                  ),
                ],
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: CyberColors.subtleBorder),
              const SizedBox(height: 10),
              Text(
                widget.thinking,
                style: AppTheme.codeFont(
                  color: CyberColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
