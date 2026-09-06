import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ChatInputBar extends StatefulWidget {
  final void Function(String prompt) onSend;
  final bool isStreaming;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.isStreaming = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final List<String> _quickPrompts = [
    '繼續執行',
    '請執行單元測試',
    '檢查程式碼並修復問題',
    '產出專案結構總覽',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty || widget.isStreaming) return;

    widget.onSend(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final effectiveBottom = bottomInset > 0 ? bottomInset + 10 : (bottomPadding > 0 ? bottomPadding + 8 : 12.0);

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: effectiveBottom,
      ),
      decoration: const BoxDecoration(
        color: CyberColors.surface,
        border: Border(
          top: BorderSide(color: CyberColors.subtleBorder, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick action chips
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickPrompts.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = _quickPrompts[index];
                return ActionChip(
                  label: Text(
                    prompt,
                    style: const TextStyle(fontSize: 11.5, color: CyberColors.textSecondary),
                  ),
                  backgroundColor: CyberColors.surfaceElevated,
                  side: const BorderSide(color: CyberColors.subtleBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () {
                    _textController.text = prompt;
                    _submit();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Input field row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: CyberColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: CyberColors.subtleBorder),
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    style: const TextStyle(color: CyberColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: '發送 Prompt 給桌面端 Agent...',
                      hintStyle: TextStyle(color: CyberColors.textMuted, fontSize: 13.5),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: widget.isStreaming
                      ? CyberColors.cardElevated
                      : CyberColors.cyan,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: widget.isStreaming
                      ? null
                      : [
                          BoxShadow(
                            color: CyberColors.cyan.withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: -1,
                          ),
                        ],
                ),
                child: IconButton(
                  icon: widget.isStreaming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(CyberColors.cyan),
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.black, size: 20),
                  onPressed: widget.isStreaming ? null : _submit,
                  tooltip: '發送指令',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
