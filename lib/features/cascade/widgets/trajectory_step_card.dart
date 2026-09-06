import 'package:flutter/material.dart';
import '../../../core/models/trajectory_step.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cyber_button.dart';
import '../../../shared/widgets/cyber_card.dart';
import '../../../shared/widgets/status_indicator.dart';
import 'code_diff_viewer.dart';
import 'user_approval_dialog.dart';

class TrajectoryStepCard extends StatefulWidget {
  final TrajectoryStep step;
  final void Function(String interactionId, bool approved, String? feedback)? onApproval;

  const TrajectoryStepCard({
    super.key,
    required this.step,
    this.onApproval,
  });

  @override
  State<TrajectoryStepCard> createState() => _TrajectoryStepCardState();
}

class _TrajectoryStepCardState extends State<TrajectoryStepCard> {
  bool _isExpanded = false;

  IconData _getToolIcon(String toolName) {
    switch (toolName) {
      case 'run_command':
        return Icons.terminal;
      case 'replace_file_content':
      case 'write_to_file':
        return Icons.code;
      case 'read_file':
      case 'view_file':
        return Icons.visibility;
      case 'grep_search':
      case 'find_by_name':
        return Icons.search;
      case 'ask_permission':
        return Icons.security;
      default:
        return Icons.build_circle_outlined;
    }
  }

  Color _getStatusColor(StepStatus status) {
    switch (status) {
      case StepStatus.running:
        return CyberColors.cyan;
      case StepStatus.waitingUserInteraction:
        return CyberColors.amber;
      case StepStatus.completed:
        return CyberColors.emerald;
      case StepStatus.failed:
      case StepStatus.rejected:
        return CyberColors.red;
    }
  }

  String _getStatusText(StepStatus status) {
    switch (status) {
      case StepStatus.running:
        return '執行中';
      case StepStatus.waitingUserInteraction:
        return '等待審批';
      case StepStatus.completed:
        return '已完成';
      case StepStatus.rejected:
        return '已拒絕';
      case StepStatus.failed:
        return '失敗';
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final statusColor = _getStatusColor(step.status);
    final isWaiting = step.status == StepStatus.waitingUserInteraction;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: CyberCard(
        borderColor: isWaiting ? CyberColors.amber : CyberColors.subtleBorder,
        hasGlow: isWaiting,
        glowColor: CyberColors.amberGlow,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_getToolIcon(step.toolName), size: 18, color: statusColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.summary,
                          style: const TextStyle(
                            color: CyberColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          step.toolName,
                          style: AppTheme.codeFont(
                            color: CyberColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusIndicator(
                          color: statusColor,
                          size: 6,
                          animate: step.status == StepStatus.running || isWaiting,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _getStatusText(step.status),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: CyberColors.textMuted,
                  ),
                ],
              ),
            ),

            // Waiting for interaction - Action Buttons
            if (isWaiting && step.interaction != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CyberColors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: CyberColors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security, color: CyberColors.amber, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          step.interaction!.title,
                          style: const TextStyle(
                            color: CyberColors.amber,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.interaction!.actionTarget,
                      style: AppTheme.codeFont(color: CyberColors.textPrimary, fontSize: 11.5),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: CyberButton(
                            text: '審批詳情',
                            isOutlined: true,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            onPressed: () {
                              UserApprovalDialog.show(
                                context,
                                request: step.interaction!,
                                onRespond: (approved, feedback) {
                                  widget.onApproval?.call(
                                    step.interaction!.interactionId,
                                    approved,
                                    feedback,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CyberButton(
                            text: '直接核准',
                            color: CyberColors.emerald,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            onPressed: () {
                              widget.onApproval?.call(
                                step.interaction!.interactionId,
                                true,
                                null,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Expandable details (Arguments, Code Diff, Output)
            if (_isExpanded) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: CyberColors.subtleBorder),
              const SizedBox(height: 10),

              if (step.description.isNotEmpty) ...[
                Text(
                  step.description,
                  style: const TextStyle(color: CyberColors.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
              ],

              // Arguments
              if (step.arguments.isNotEmpty) ...[
                const Text(
                  '呼叫參數 (Arguments):',
                  style: TextStyle(color: CyberColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CyberColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final entry in step.arguments.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: RichText(
                            text: TextSpan(
                              style: AppTheme.codeFont(fontSize: 11.5),
                              children: [
                                TextSpan(text: '${entry.key}: ', style: const TextStyle(color: CyberColors.cyan)),
                                TextSpan(text: '${entry.value}', style: const TextStyle(color: CyberColors.textPrimary)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Code Diff Viewer
              if (step.codeDiff != null) ...[
                const Text(
                  '代碼變更 (Diff):',
                  style: TextStyle(color: CyberColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                CodeDiffViewer(diff: step.codeDiff!),
                const SizedBox(height: 8),
              ],

              // Output
              if (step.output != null) ...[
                const Text(
                  '執行結果 (Output):',
                  style: TextStyle(color: CyberColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CyberColors.terminalBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: CyberColors.subtleBorder),
                  ),
                  child: Text(
                    step.output!,
                    style: AppTheme.codeFont(
                      color: CyberColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
