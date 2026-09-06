import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/terminal_stream.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ansi_parser.dart';
import '../../../shared/widgets/cyber_card.dart';

class TerminalConsoleCard extends StatefulWidget {
  final List<TerminalChunk> chunks;
  final void Function(String input) onSendInput;
  final void Function(String shortcut) onShortcut;
  final VoidCallback onClear;

  const TerminalConsoleCard({
    super.key,
    required this.chunks,
    required this.onSendInput,
    required this.onShortcut,
    required this.onClear,
  });

  @override
  State<TerminalConsoleCard> createState() => _TerminalConsoleCardState();
}

class _TerminalConsoleCardState extends State<TerminalConsoleCard> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  bool _userScrolledUp = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final pos = _scrollController.position;
      final isNearBottom = (pos.maxScrollExtent - pos.pixels) <= 100;
      if (isNearBottom && _userScrolledUp) {
        setState(() => _userScrolledUp = false);
      } else if (!isNearBottom && !_userScrolledUp) {
        setState(() => _userScrolledUp = true);
      }
    }
  }

  @override
  void didUpdateWidget(TerminalConsoleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chunks.length != widget.chunks.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        final pos = _scrollController.position;
        final isNearBottom = (pos.maxScrollExtent - pos.pixels) <= 100;

        // 若使用者正在向上翻閱歷史且非強制操作，則不強制捲動 (Issue #20)
        if (!force && _userScrolledUp) {
          return;
        }

        if (force || isNearBottom) {
          _scrollController.animateTo(
            pos.maxScrollExtent,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
          );
          if (_userScrolledUp) {
            setState(() => _userScrolledUp = false);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _inputController.text;
    if (text.isEmpty) return;
    widget.onSendInput(text);
    _inputController.clear();
    _scrollToBottom(force: true);
  }

  void _copyLogs() {
    final allText = widget.chunks.map((c) => c.text).join();
    Clipboard.setData(ClipboardData(text: allText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已複製全部終端日誌至剪貼簿'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CyberCard(
      backgroundColor: CyberColors.terminalBg,
      borderColor: CyberColors.subtleBorder,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Console Header Bar (Flexible to prevent narrow overflow - Issue #21)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: CyberColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: CyberColors.subtleBorder)),
            ),
            child: Row(
              children: [
                // Mac terminal traffic dots
                Row(
                  children: [
                    Container(width: 9, height: 9, decoration: const BoxDecoration(color: CyberColors.red, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Container(width: 9, height: 9, decoration: const BoxDecoration(color: CyberColors.amber, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Container(width: 9, height: 9, decoration: const BoxDecoration(color: CyberColors.emerald, shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'bash / zsh - Remote Terminal Output',
                    style: TextStyle(color: CyberColors.textMuted, fontSize: 11.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_all, size: 16, color: CyberColors.textMuted),
                  onPressed: _copyLogs,
                  tooltip: '複製全部終端日誌',
                  splashRadius: 16,
                ),
                IconButton(
                  icon: const Icon(Icons.clear_all, size: 16, color: CyberColors.textMuted),
                  onPressed: widget.onClear,
                  tooltip: '清空終端畫面',
                  splashRadius: 16,
                ),
              ],
            ),
          ),

          // Log Window with Smart Follow & Jump Button (Issue #20, #24)
          Expanded(
            child: Stack(
              children: [
                SelectionArea(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: widget.chunks.length,
                    itemBuilder: (context, index) {
                      final chunk = widget.chunks[index];
                      if (chunk.isSystem) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            chunk.text,
                            style: const TextStyle(
                              color: CyberColors.amber,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        );
                      }
                      return SelectableText.rich(
                        AnsiParser.parseToSpan(
                          chunk.text,
                          defaultColor: chunk.isError ? CyberColors.red : CyberColors.terminalText,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                if (_userScrolledUp)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: InkWell(
                      onTap: () => _scrollToBottom(force: true),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: CyberColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: CyberColors.cyan.withOpacity(0.6)),
                          boxShadow: [
                            BoxShadow(
                              color: CyberColors.cyan.withOpacity(0.2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_downward, size: 13, color: CyberColors.cyan),
                            SizedBox(width: 4),
                            Text('回到底部', style: TextStyle(color: CyberColors.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Shortcut bar (Ctrl+C, Enter, Tab, clear) with accessible hit targets (Issue #26)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: CyberColors.surface,
              border: Border(top: BorderSide(color: CyberColors.subtleBorder)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildShortcutChip(
                    'Ctrl+C',
                    () => widget.onShortcut('Ctrl+C'),
                    tooltip: '中斷遠端終端程序 (SIGINT)',
                    isRed: true,
                  ),
                  const SizedBox(width: 8),
                  _buildShortcutChip(
                    'Enter ↵',
                    () => widget.onShortcut('Enter'),
                    tooltip: '發送換行 (Enter)',
                  ),
                  const SizedBox(width: 8),
                  _buildShortcutChip(
                    'Tab ⇥',
                    () => widget.onShortcut('Tab'),
                    tooltip: '發送 Tab 補全鍵',
                  ),
                  const SizedBox(width: 8),
                  _buildShortcutChip(
                    'clear',
                    () => widget.onShortcut('clear'),
                    tooltip: '清空本機終端輸出畫面',
                  ),
                ],
              ),
            ),
          ),

          // Input Line
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: CyberColors.surfaceElevated,
            child: Row(
              children: [
                const Text('➜ ', style: TextStyle(color: CyberColors.cyan, fontWeight: FontWeight.bold)),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: AppTheme.codeFont(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '輸入指令並發送至本機終端...',
                      hintStyle: TextStyle(color: CyberColors.textMuted, fontSize: 12),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, size: 16, color: CyberColors.cyan),
                  onPressed: _submit,
                  splashRadius: 16,
                  tooltip: '發送按鍵',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutChip(
    String label,
    VoidCallback onTap, {
    required String tooltip,
    bool isRed = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isRed ? CyberColors.red.withOpacity(0.15) : CyberColors.surfaceElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isRed ? CyberColors.red.withOpacity(0.4) : CyberColors.subtleBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isRed ? CyberColors.red : CyberColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
