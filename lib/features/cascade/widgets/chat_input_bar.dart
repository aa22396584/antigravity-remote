import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class ChatInputBar extends StatefulWidget {
  final FutureOr<void> Function(String prompt) onSend;
  final VoidCallback? onStop;
  final bool isStreaming;
  final String? initialText;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.onStop,
    this.isStreaming = false,
    this.initialText,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;

  final List<String> _quickPrompts = [
    '繼續執行',
    '請執行單元測試',
    '檢查程式碼並修復問題',
    '產出專案結構總覽',
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty || widget.isStreaming || _isSending) return;

    final draftSnapshot = _textController.text;
    _textController.clear();
    setState(() => _isSending = true);

    try {
      await widget.onSend(text);
    } catch (_) {
      // 若發送出現異常，復原草稿以便使用者修改或重試 (Issue #19)
      if (mounted) {
        _textController.text = draftSnapshot;
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _onChipTapped(String prompt) {
    if (widget.isStreaming) return;
    final current = _textController.text;
    if (current.trim().isEmpty) {
      _textController.text = prompt;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: prompt.length),
      );
      _submit();
    } else {
      // 若已有草稿，不靜默覆寫，而是追加提示詞至草稿後 (Issue #19)
      final newText = '$current\n$prompt';
      _textController.text = newText;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final effectiveBottom = bottomInset > 0
        ? bottomInset + 8
        : (bottomPadding > 0 ? bottomPadding + 6 : 10.0);

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
          // Quick action chips with touch target and streaming protection
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickPrompts.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = _quickPrompts[index];
                final isEnabled = !widget.isStreaming && !_isSending;
                return ActionChip(
                  label: Text(
                    prompt,
                    style: TextStyle(
                      fontSize: 12,
                      color: isEnabled ? CyberColors.textSecondary : CyberColors.textMuted,
                    ),
                  ),
                  backgroundColor: CyberColors.surfaceElevated,
                  side: const BorderSide(color: CyberColors.subtleBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  onPressed: isEnabled ? () => _onChipTapped(prompt) : null,
                  tooltip: isEnabled ? '點擊填入/發送提示詞' : '串流進行中，禁止覆寫草稿',
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
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        _submit();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: CyberColors.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: '發送 Prompt 給桌面端 Agent (Enter 送出, Shift+Enter 換行)...',
                        hintStyle: TextStyle(color: CyberColors.textMuted, fontSize: 13),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Action Button (Send / Stop / Sending Spinner)
              Container(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                decoration: BoxDecoration(
                  color: widget.isStreaming
                      ? CyberColors.red.withOpacity(0.9)
                      : (_isSending ? CyberColors.cardElevated : CyberColors.cyan),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: widget.isStreaming
                      ? [
                          BoxShadow(
                            color: CyberColors.red.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: -1,
                          ),
                        ]
                      : (_isSending
                          ? null
                          : [
                              BoxShadow(
                                color: CyberColors.cyan.withOpacity(0.4),
                                blurRadius: 10,
                                spreadRadius: -1,
                              ),
                            ]),
                ),
                child: widget.isStreaming
                    ? IconButton(
                        icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 22),
                        onPressed: widget.onStop,
                        tooltip: '中止遠端任務 (Stop Task)',
                      )
                    : (_isSending
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(CyberColors.cyan),
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send, color: Colors.black, size: 20),
                            onPressed: _submit,
                            tooltip: '發送指令',
                          )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
