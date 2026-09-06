import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/user_interaction.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cyber_button.dart';
import '../../../shared/widgets/cyber_card.dart';

class UserApprovalDialog extends StatefulWidget {
  final UserInteractionRequest request;
  final void Function(bool approved, String? feedback) onRespond;

  const UserApprovalDialog({
    super.key,
    required this.request,
    required this.onRespond,
  });

  static Future<void> show(
    BuildContext context, {
    required UserInteractionRequest request,
    required void Function(bool approved, String? feedback) onRespond,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UserApprovalDialog(
        request: request,
        onRespond: onRespond,
      ),
    );
  }

  @override
  State<UserApprovalDialog> createState() => _UserApprovalDialogState();
}

class _UserApprovalDialogState extends State<UserApprovalDialog> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _showFeedbackInput = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  bool _isDestructive(String target) {
    final lower = target.toLowerCase();
    return lower.contains('rm ') ||
        lower.contains('sudo') ||
        lower.contains('kill') ||
        lower.contains('reset --hard') ||
        lower.contains('drop') ||
        lower.contains('delete') ||
        lower.contains('truncate');
  }

  void _copyTarget(BuildContext context, String target) {
    Clipboard.setData(ClipboardData(text: target));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已複製指令/目標至剪貼簿'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final isDestructive = req.isDestructive || _isDestructive(req.actionTarget);
    final isCommand = req.actionName == 'command' || req.type == UserInteractionType.askPermission;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          left: 16,
          right: 16,
          top: 10,
        ),
        decoration: const BoxDecoration(
          color: CyberColors.cardElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: CyberColors.amber, width: 2),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: CyberColors.textMuted.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header with Type Icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CyberColors.amber.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCommand ? Icons.terminal : Icons.security,
                      color: CyberColors.amber,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: CyberColors.textPrimary,
                          ),
                        ),
                        Text(
                          '桌面端 Antigravity 正在等待授權執行',
                          style: TextStyle(
                            fontSize: 12,
                            color: CyberColors.amber.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Destructive Warning Banner (Heuristic disclaimer - Issue #27)
              if (isDestructive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: CyberColors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CyberColors.red.withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: CyberColors.red, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '注意：此操作包含潛在破壞性指令，請謹慎審查！',
                          style: TextStyle(color: CyberColors.red, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Description
              if (req.description.isNotEmpty) ...[
                Text(
                  req.description,
                  style: const TextStyle(color: CyberColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 10),
              ],

              // Target Box with Typed presentation & One-click Copy (Issue #27)
              CyberCard(
                backgroundColor: CyberColors.terminalBg,
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCommand)
                      const Text('\$ ', style: TextStyle(color: CyberColors.emerald, fontSize: 13, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: SelectableText(
                        req.actionTarget,
                        style: AppTheme.codeFont(
                          color: CyberColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16, color: CyberColors.cyan),
                      onPressed: () => _copyTarget(context, req.actionTarget),
                      tooltip: '複製完整指令/目標',
                      splashRadius: 16,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Write-in Feedback Input (Accessible TextButton - Issue #26)
              if (_showFeedbackInput) ...[
                TextField(
                  controller: _feedbackController,
                  style: const TextStyle(color: CyberColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: '輸入指示或拒絕原因 (可選)...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
              ] else ...[
                TextButton.icon(
                  onPressed: () => setState(() => _showFeedbackInput = true),
                  icon: const Icon(Icons.add_comment_outlined, size: 16, color: CyberColors.cyan),
                  label: const Text(
                    '+ 附加補充指示或拒絕說明',
                    style: TextStyle(color: CyberColors.cyan, fontSize: 12.5),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    minimumSize: const Size(0, 40),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Action Buttons with Accessible Minimum Touch Target (Issue #26)
              Row(
                children: [
                  Expanded(
                    child: CyberButton(
                      text: '拒絕 (Reject)',
                      color: CyberColors.red,
                      isOutlined: true,
                      icon: Icons.close,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      onPressed: () {
                        final feedback = _feedbackController.text.trim();
                        widget.onRespond(false, feedback.isNotEmpty ? feedback : null);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CyberButton(
                      text: '核准執行 (Approve)',
                      color: CyberColors.emerald,
                      icon: Icons.check,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      onPressed: () {
                        final feedback = _feedbackController.text.trim();
                        widget.onRespond(true, feedback.isNotEmpty ? feedback : null);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
