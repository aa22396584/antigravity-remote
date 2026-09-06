import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/cascade_message.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cyber_button.dart';
import '../../../shared/widgets/cyber_card.dart';
import '../../device/providers/device_provider.dart';
import '../../device/widgets/transport_badge.dart';
import '../providers/cascade_provider.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/thinking_card.dart';
import '../widgets/trajectory_step_card.dart';
import '../widgets/user_approval_dialog.dart';

class CascadeChatView extends ConsumerStatefulWidget {
  final VoidCallback? onOpenTerminal;

  const CascadeChatView({
    super.key,
    this.onOpenTerminal,
  });

  @override
  ConsumerState<CascadeChatView> createState() => _CascadeChatViewState();
}

class _CascadeChatViewState extends ConsumerState<CascadeChatView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cascadeState = ref.watch(cascadeProvider);
    final cascadeNotifier = ref.read(cascadeProvider.notifier);
    final deviceState = ref.watch(deviceProvider);

    ref.listen<CascadeState>(cascadeProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          prev?.pendingInteraction != next.pendingInteraction ||
          prev?.isStreaming != next.isStreaming) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deviceState.activeDevice?.name ?? 'Antigravity Agent',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
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
        actions: [
          if (widget.onOpenTerminal != null)
            IconButton(
              icon: const Icon(Icons.terminal, color: CyberColors.cyan),
              onPressed: widget.onOpenTerminal,
              tooltip: '即時終端輸出',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: CyberColors.textSecondary),
            onSelected: (val) {
              if (val == 'clear') {
                cascadeNotifier.clearConversation();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: CyberColors.red),
                    SizedBox(width: 8),
                    Text('清空對話歷史', style: TextStyle(color: CyberColors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Pending Approval Alert Banner (Sticky)
          if (cascadeState.pendingInteraction != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: CyberColors.amber.withOpacity(0.15),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: CyberColors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Agent 請求指令審批：${cascadeState.pendingInteraction!.actionTarget}',
                      style: const TextStyle(
                        color: CyberColors.amber,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CyberButton(
                    text: '立即審批',
                    color: CyberColors.amber,
                    textColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    onPressed: () {
                      UserApprovalDialog.show(
                        context,
                        request: cascadeState.pendingInteraction!,
                        onRespond: (approved, feedback) {
                          cascadeNotifier.handleApproval(
                            interactionId: cascadeState.pendingInteraction!.interactionId,
                            approved: approved,
                            feedback: feedback,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],

          // 2. Chat Messages Stream
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: cascadeState.messages.length,
              itemBuilder: (context, index) {
                final message = cascadeState.messages[index];
                return _buildMessageItem(message, cascadeNotifier);
              },
            ),
          ),

          // 3. Bottom Chat Input Bar
          ChatInputBar(
            isStreaming: cascadeState.isStreaming,
            onSend: (prompt) => cascadeNotifier.sendPrompt(prompt),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(CascadeMessage message, CascadeNotifier notifier) {
    if (message.role == MessageRole.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: CyberColors.surfaceElevated,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: CyberColors.cyan.withOpacity(0.3)),
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              color: CyberColors.textPrimary,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    // Assistant message with Thinking + Steps + Markdown
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thinking block
          if (message.thinking != null || message.isThinking)
            ThinkingCard(
              thinking: message.thinking ?? '',
              isThinking: message.isThinking,
              duration: message.thinkingDuration,
              initiallyExpanded: true,
            ),

          // Trajectory Steps
          for (final step in message.trajectorySteps)
            TrajectoryStepCard(
              step: step,
              onApproval: (id, approved, feedback) {
                notifier.handleApproval(
                  interactionId: id,
                  approved: approved,
                  feedback: feedback,
                );
              },
            ),

          // Final response markdown
          if (message.content.isNotEmpty)
            CyberCard(
              backgroundColor: CyberColors.surface,
              borderColor: CyberColors.subtleBorder,
              padding: const EdgeInsets.all(16),
              child: MarkdownBody(
                data: message.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: const TextStyle(color: CyberColors.textPrimary, fontSize: 14, height: 1.5),
                  h1: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  h2: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  h3: const TextStyle(color: CyberColors.cyan, fontSize: 15, fontWeight: FontWeight.bold),
                  code: AppTheme.codeFont(
                    color: CyberColors.cyan,
                    fontSize: 12.5,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: CyberColors.terminalBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CyberColors.subtleBorder),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
