import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _userScrolledUp = false;
  bool _hasUnreadUpdates = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final pos = _scrollController.position;
      final isNearBottom = (pos.maxScrollExtent - pos.pixels) <= 140;
      if (isNearBottom && _userScrolledUp) {
        setState(() {
          _userScrolledUp = false;
          _hasUnreadUpdates = false;
        });
      } else if (!isNearBottom && !_userScrolledUp) {
        setState(() {
          _userScrolledUp = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool smooth = true, bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        final pos = _scrollController.position;
        final isNearBottom = (pos.maxScrollExtent - pos.pixels) <= 140;

        // 手勢保護：若使用者正手動上滑查閱歷史且非強制，則不打斷閱讀 (Issue #20)
        if (!force && _userScrolledUp) {
          setState(() {
            _hasUnreadUpdates = true;
          });
          return;
        }

        if (force || isNearBottom) {
          final maxScroll = pos.maxScrollExtent;
          if (smooth) {
            _scrollController.animateTo(
              maxScroll,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
            );
          } else {
            _scrollController.jumpTo(maxScroll);
          }
          if (_userScrolledUp) {
            setState(() {
              _userScrolledUp = false;
              _hasUnreadUpdates = false;
            });
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cascadeState = ref.watch(cascadeProvider);
    final cascadeNotifier = ref.read(cascadeProvider.notifier);
    final deviceState = ref.watch(deviceProvider);
    final messenger = ScaffoldMessenger.of(context);

    ref.listen<CascadeState>(cascadeProvider, (prev, next) {
      if (next.errorMessage != null && prev?.errorMessage != next.errorMessage) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: CyberColors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      final prevLast = prev?.messages.isNotEmpty == true ? prev!.messages.last : null;
      final nextLast = next.messages.isNotEmpty == true ? next.messages.last : null;
      final contentChanged = prevLast?.content != nextLast?.content ||
          prevLast?.thinking != nextLast?.thinking ||
          prevLast?.trajectorySteps.length != nextLast?.trajectorySteps.length;

      final newMsgAdded = prev?.messages.length != next.messages.length;
      final newInteraction = prev?.pendingInteraction != next.pendingInteraction &&
          next.pendingInteraction != null;

      if (newMsgAdded || newInteraction) {
        _scrollToBottom(force: true);
      } else if (contentChanged || prev?.isStreaming != next.isStreaming) {
        _scrollToBottom(force: false);
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
                        onRespond: (approved, feedback) async {
                          try {
                            await cascadeNotifier.handleApproval(
                              interactionId: cascadeState.pendingInteraction!.interactionId,
                              approved: approved,
                              feedback: feedback,
                            );
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('審批提交失敗: $e'),
                                  backgroundColor: CyberColors.red,
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],

          // 2. Chat Messages Stream with Smart Scroll & Jump Button
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: cascadeState.messages.length,
                  itemBuilder: (context, index) {
                    final message = cascadeState.messages[index];
                    return _buildMessageItem(message, cascadeNotifier);
                  },
                ),
                if (_userScrolledUp) _buildScrollToBottomPill(),
              ],
            ),
          ),

          // 3. Bottom Chat Input Bar with Stop & Safety
          ChatInputBar(
            isStreaming: cascadeState.isStreaming,
            onSend: (prompt) => cascadeNotifier.sendPrompt(prompt),
            onStop: () => cascadeNotifier.cancelActiveTask(),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToBottomPill() {
    return Positioned(
      bottom: 12,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _scrollToBottom(smooth: true, force: true);
            setState(() {
              _userScrolledUp = false;
              _hasUnreadUpdates = false;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CyberColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CyberColors.cyan.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(
                  color: CyberColors.cyan.withOpacity(0.25),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasUnreadUpdates)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: CyberColors.cyan,
                      shape: BoxShape.circle,
                    ),
                  ),
                const Text(
                  '回到即時 ⇣',
                  style: TextStyle(
                    color: CyberColors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(CascadeMessage message, CascadeNotifier notifier) {
    final messenger = ScaffoldMessenger.of(context);

    // User Message with Delivery Status & Retry (Issue #19)
    if (message.role == MessageRole.user) {
      final isFailed = message.deliveryStatus == MessageDeliveryStatus.failed;
      final isSending = message.deliveryStatus == MessageDeliveryStatus.sending;

      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isFailed ? CyberColors.red.withOpacity(0.12) : CyberColors.surfaceElevated,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                  border: Border.all(
                    color: isFailed ? CyberColors.red.withOpacity(0.6) : CyberColors.cyan.withOpacity(0.3),
                  ),
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
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSending) ...[
                    const SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(CyberColors.cyan),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('傳送中...', style: TextStyle(color: CyberColors.textMuted, fontSize: 11)),
                  ] else if (isFailed) ...[
                    const Icon(Icons.error_outline, size: 13, color: CyberColors.red),
                    const SizedBox(width: 4),
                    const Text('發送失敗', style: TextStyle(color: CyberColors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => notifier.retrySendMessage(message.id),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text('重試 ↻', style: TextStyle(color: CyberColors.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Assistant message with Thinking + Steps + Markdown + Safe Link (Issue #27)
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
              onApproval: (id, approved, feedback) async {
                try {
                  await notifier.handleApproval(
                    interactionId: id,
                    approved: approved,
                    feedback: feedback,
                  );
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('審批提交失敗: $e'),
                        backgroundColor: CyberColors.red,
                      ),
                    );
                  }
                }
              },
            ),

          // Final response markdown with Safe URL policy (Issue #27)
          if (message.content.isNotEmpty)
            CyberCard(
              backgroundColor: CyberColors.surface,
              borderColor: CyberColors.subtleBorder,
              padding: const EdgeInsets.all(16),
              child: MarkdownBody(
                data: message.content,
                selectable: true,
                onTapLink: (text, href, title) async {
                  if (href == null) return;
                  final uri = Uri.tryParse(href);
                  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
                    final canLaunch = await canLaunchUrl(uri);
                    if (canLaunch) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('已阻止非安全之外部連結協議 (僅允許 http/https)'),
                        backgroundColor: CyberColors.red,
                      ),
                    );
                  }
                },
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
