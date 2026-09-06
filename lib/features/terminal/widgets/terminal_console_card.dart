import 'package:flutter/material.dart';
import '../../../core/models/terminal_stream.dart';
import '../../../core/theme/app_theme.dart';
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

  @override
  void didUpdateWidget(TerminalConsoleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chunks.length != widget.chunks.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _inputController.text;
    if (text.isEmpty) return;
    widget.onSendInput(text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return CyberCard(
      backgroundColor: CyberColors.terminalBg,
      borderColor: CyberColors.subtleBorder,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Console Header Bar
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
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: CyberColors.red, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: CyberColors.amber, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: CyberColors.emerald, shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(width: 14),
                const Text(
                  'bash / zsh - Remote Terminal Output',
                  style: TextStyle(color: CyberColors.textMuted, fontSize: 11.5),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.clear_all, size: 16, color: CyberColors.textMuted),
                  onPressed: widget.onClear,
                  tooltip: '清空終端',
                  splashRadius: 16,
                ),
              ],
            ),
          ),

          // Log Window
          Expanded(
            child: SelectionArea(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: widget.chunks.length,
                itemBuilder: (context, index) {
                  final chunk = widget.chunks[index];
                  return Text(
                    chunk.text,
                    style: AppTheme.codeFont(
                      color: chunk.isError ? CyberColors.red : CyberColors.terminalText,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ),

          // Shortcut bar (Ctrl+C, Enter, Tab)
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
                  _buildShortcutChip('Ctrl+C', () => widget.onShortcut('Ctrl+C'), isRed: true),
                  const SizedBox(width: 6),
                  _buildShortcutChip('Enter ↵', () => widget.onShortcut('Enter')),
                  const SizedBox(width: 6),
                  _buildShortcutChip('Tab ⇥', () => widget.onShortcut('Tab')),
                  const SizedBox(width: 6),
                  _buildShortcutChip('clear', () => widget.onShortcut('clear')),
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

  Widget _buildShortcutChip(String label, VoidCallback onTap, {bool isRed = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
