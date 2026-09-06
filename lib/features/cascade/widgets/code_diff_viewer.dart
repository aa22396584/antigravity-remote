import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

enum _DiffLineType {
  header,
  hunk,
  added,
  deleted,
  context,
}

class _ParsedDiffLine {
  final _DiffLineType type;
  final int? oldLine;
  final int? newLine;
  final String text;

  const _ParsedDiffLine({
    required this.type,
    this.oldLine,
    this.newLine,
    required this.text,
  });
}

class CodeDiffViewer extends StatefulWidget {
  final String diff;
  final String? fileName;

  const CodeDiffViewer({
    super.key,
    required this.diff,
    this.fileName,
  });

  @override
  State<CodeDiffViewer> createState() => _CodeDiffViewerState();
}

class _CodeDiffViewerState extends State<CodeDiffViewer> {
  bool _expanded = false;
  static const int _maxInitialLines = 150;

  List<_ParsedDiffLine> _parseDiff(String rawDiff) {
    final lines = rawDiff.split('\n');
    final parsed = <_ParsedDiffLine>[];

    int? currentOld;
    int? currentNew;

    final hunkRegex = RegExp(r'^@@\s+-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@');

    for (final line in lines) {
      final hunkMatch = hunkRegex.firstMatch(line);
      if (hunkMatch != null) {
        currentOld = int.tryParse(hunkMatch.group(1) ?? '');
        currentNew = int.tryParse(hunkMatch.group(3) ?? '');
        parsed.add(_ParsedDiffLine(
          type: _DiffLineType.hunk,
          text: line,
        ));
      } else if (line.startsWith('+++') || line.startsWith('---') || line.startsWith('diff --git')) {
        parsed.add(_ParsedDiffLine(
          type: _DiffLineType.header,
          text: line,
        ));
      } else if (line.startsWith('+')) {
        parsed.add(_ParsedDiffLine(
          type: _DiffLineType.added,
          newLine: currentNew,
          text: line.length > 1 ? line.substring(1) : '',
        ));
        if (currentNew != null) currentNew++;
      } else if (line.startsWith('-')) {
        parsed.add(_ParsedDiffLine(
          type: _DiffLineType.deleted,
          oldLine: currentOld,
          text: line.length > 1 ? line.substring(1) : '',
        ));
        if (currentOld != null) currentOld++;
      } else {
        final content = line.startsWith(' ') && line.length > 1 ? line.substring(1) : line;
        parsed.add(_ParsedDiffLine(
          type: _DiffLineType.context,
          oldLine: currentOld,
          newLine: currentNew,
          text: content,
        ));
        if (currentOld != null) currentOld++;
        if (currentNew != null) currentNew++;
      }
    }
    return parsed;
  }

  void _copyDiff(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.diff));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已複製完整 Diff 至剪貼簿'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyAddedCode(BuildContext context, List<_ParsedDiffLine> parsed) {
    final addedLines = parsed
        .where((l) => l.type == _DiffLineType.added)
        .map((l) => l.text)
        .join('\n');
    Clipboard.setData(ClipboardData(text: addedLines.isNotEmpty ? addedLines : widget.diff));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已複製變更代碼至剪貼簿'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String? _detectFileName(String rawDiff) {
    if (widget.fileName != null && widget.fileName!.isNotEmpty) {
      return widget.fileName;
    }
    for (final line in rawDiff.split('\n')) {
      if (line.startsWith('+++ b/')) {
        return line.substring(6).trim();
      } else if (line.startsWith('--- a/')) {
        return line.substring(6).trim();
      } else if (line.startsWith('diff --git a/')) {
        final parts = line.split(' ');
        if (parts.length >= 3 && parts[2].startsWith('a/')) {
          return parts[2].substring(2).trim();
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parseDiff(widget.diff);
    final isLong = parsed.length > _maxInitialLines;
    final visibleLines = (isLong && !_expanded) ? parsed.sublist(0, _maxInitialLines) : parsed;
    final displayFileName = _detectFileName(widget.diff) ?? 'Unified Code Diff';

    int additions = parsed.where((l) => l.type == _DiffLineType.added).length;
    int deletions = parsed.where((l) => l.type == _DiffLineType.deleted).length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: CyberColors.terminalBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CyberColors.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with File Context & Copy Actions (Issue #27)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: CyberColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
              border: Border(bottom: BorderSide(color: CyberColors.subtleBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.code, size: 16, color: CyberColors.cyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayFileName,
                    style: AppTheme.codeFont(
                      color: CyberColors.textPrimary,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Stats badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: CyberColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('+$additions', style: const TextStyle(color: CyberColors.emerald, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Text('-$deletions', style: const TextStyle(color: CyberColors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: CyberColors.textMuted),
                  onPressed: () => _copyDiff(context),
                  tooltip: '複製完整 Diff',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
                IconButton(
                  icon: const Icon(Icons.content_copy_outlined, size: 16, color: CyberColors.cyan),
                  onPressed: () => _copyAddedCode(context, parsed),
                  tooltip: '複製變更內容',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
              ],
            ),
          ),

          // Horizontal scrollable unified diff body with line numbers gutter (Issue #27, #21)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in visibleLines) _buildDiffRow(line),
                ],
              ),
            ),
          ),

          // Expansion Toggle for Long Diffs (Issue #24)
          if (isLong && !_expanded)
            InkWell(
              onTap: () => setState(() => _expanded = true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: CyberColors.surfaceElevated,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(9)),
                  border: Border(top: BorderSide(color: CyberColors.subtleBorder)),
                ),
                child: Text(
                  '展開剩餘 ${parsed.length - _maxInitialLines} 行代碼差異 ⇣',
                  style: const TextStyle(color: CyberColors.cyan, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiffRow(_ParsedDiffLine line) {
    Color textColor = CyberColors.textSecondary;
    Color bgColor = Colors.transparent;
    String sign = ' ';

    switch (line.type) {
      case _DiffLineType.added:
        textColor = CyberColors.emerald;
        bgColor = CyberColors.emerald.withOpacity(0.12);
        sign = '+';
        break;
      case _DiffLineType.deleted:
        textColor = CyberColors.red;
        bgColor = CyberColors.red.withOpacity(0.12);
        sign = '-';
        break;
      case _DiffLineType.hunk:
        textColor = CyberColors.cyan;
        bgColor = CyberColors.cyan.withOpacity(0.08);
        sign = '@';
        break;
      case _DiffLineType.header:
        textColor = CyberColors.textMuted;
        bgColor = CyberColors.surfaceElevated.withOpacity(0.5);
        break;
      case _DiffLineType.context:
        break;
    }

    if (line.type == _DiffLineType.hunk || line.type == _DiffLineType.header) {
      return Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          line.text,
          style: AppTheme.codeFont(
            color: textColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final oldStr = line.oldLine != null ? line.oldLine.toString() : '';
    final newStr = line.newLine != null ? line.newLine.toString() : '';

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Old line number gutter
          SizedBox(
            width: 32,
            child: Text(
              oldStr,
              textAlign: TextAlign.right,
              style: AppTheme.codeFont(color: CyberColors.textMuted.withOpacity(0.5), fontSize: 11),
            ),
          ),
          const SizedBox(width: 6),
          // New line number gutter
          SizedBox(
            width: 32,
            child: Text(
              newStr,
              textAlign: TextAlign.right,
              style: AppTheme.codeFont(color: CyberColors.textMuted.withOpacity(0.5), fontSize: 11),
            ),
          ),
          const SizedBox(width: 6),
          // Sign
          SizedBox(
            width: 14,
            child: Text(
              sign,
              style: AppTheme.codeFont(color: textColor, fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
          // Code Text
          SelectableText(
            line.text,
            style: AppTheme.codeFont(
              color: textColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
