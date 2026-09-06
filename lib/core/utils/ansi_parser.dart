import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ANSI Escape Code 解析與著色過濾處理器
class AnsiParser {
  static final RegExp _ansiRegex = RegExp(
    r'\x1B(?:\[(\??[0-9;]*)([a-zA-Z])|\][^\x07\x1B]*(?:\x07|\x1B\\)|[\(\)][a-zA-Z0-9]|[=>M])',
  );

  /// 將包含 ANSI Escape Sequence 之字串解析為具備顏色與樣式的 TextSpan
  static TextSpan parseToSpan(
    String text, {
    Color? defaultColor,
    double fontSize = 12,
  }) {
    final baseColor = defaultColor ?? CyberColors.terminalText;
    if (!_ansiRegex.hasMatch(text)) {
      return TextSpan(
        text: text,
        style: AppTheme.codeFont(color: baseColor, fontSize: fontSize),
      );
    }

    final spans = <InlineSpan>[];

    Color currentColor = baseColor;
    FontWeight currentWeight = FontWeight.normal;

    int lastIndex = 0;
    for (final match in _ansiRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        final segment = text.substring(lastIndex, match.start);
        spans.add(
          TextSpan(
            text: segment,
            style: AppTheme.codeFont(
              color: currentColor,
              fontSize: fontSize,
            ).copyWith(fontWeight: currentWeight),
          ),
        );
      }

      final codes = match.group(1) ?? '';
      final command = match.group(2) ?? '';

      // 'm' 代表 SGR (Select Graphic Rendition) 樣式指令
      if (command == 'm') {
        if (codes.isEmpty || codes == '0' || codes == '00') {
          currentColor = baseColor;
          currentWeight = FontWeight.normal;
        } else {
          final parts = codes.split(';');
          int i = 0;
          while (i < parts.length) {
            final code = int.tryParse(parts[i]);
            if (code == null) {
              i++;
              continue;
            }

            // 支援 24-bit TrueColor (38;2;r;g;b) 與 256 色 (38;5;n)
            if (code == 38 && i + 1 < parts.length) {
              final mode = int.tryParse(parts[i + 1]);
              if (mode == 2 && i + 4 < parts.length) {
                final r = int.tryParse(parts[i + 2]) ?? 0;
                final g = int.tryParse(parts[i + 3]) ?? 0;
                final b = int.tryParse(parts[i + 4]) ?? 0;
                currentColor = Color.fromRGBO(
                  r.clamp(0, 255),
                  g.clamp(0, 255),
                  b.clamp(0, 255),
                  1.0,
                );
                i += 5;
                continue;
              } else if (mode == 5 && i + 2 < parts.length) {
                final colorIdx = int.tryParse(parts[i + 2]) ?? 0;
                currentColor = _parse256Color(
                  colorIdx,
                  defaultColor: baseColor,
                );
                i += 3;
                continue;
              }
            }

            switch (code) {
              case 0:
                currentColor = baseColor;
                currentWeight = FontWeight.normal;
                break;
              case 1:
                currentWeight = FontWeight.bold;
                break;
              case 2:
              case 22:
                currentWeight = FontWeight.normal;
                break;
              case 30:
                currentColor = Colors.black;
                break;
              case 31:
              case 91:
                currentColor = CyberColors.red;
                break;
              case 32:
              case 92:
                currentColor = CyberColors.emerald;
                break;
              case 33:
              case 93:
                currentColor = CyberColors.amber;
                break;
              case 34:
              case 94:
                currentColor = const Color(0xFF60A5FA); // Light Blue
                break;
              case 35:
              case 95:
                currentColor = const Color(0xFFC084FC); // Purple
                break;
              case 36:
              case 96:
                currentColor = CyberColors.cyan;
                break;
              case 37:
              case 97:
                currentColor = Colors.white;
                break;
              case 39:
                currentColor = baseColor;
                break;
              case 90:
                currentColor = CyberColors.textMuted;
                break;
            }
            i++;
          }
        }
      }
      // 非 'm' 之指令（如 OSC 標題、\x1B[2K 游標等）自動被乾淨過濾剔除

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: AppTheme.codeFont(
            color: currentColor,
            fontSize: fontSize,
          ).copyWith(fontWeight: currentWeight),
        ),
      );
    }

    if (spans.isEmpty) {
      return TextSpan(
        text: text,
        style: AppTheme.codeFont(color: baseColor, fontSize: fontSize),
      );
    }

    return TextSpan(children: spans);
  }

  /// 256 色色碼對映
  static Color _parse256Color(int idx, {required Color defaultColor}) {
    if (idx < 0 || idx > 255) return defaultColor;
    if (idx == 0) return Colors.black;
    if (idx == 1) return CyberColors.red;
    if (idx == 2) return CyberColors.emerald;
    if (idx == 3) return CyberColors.amber;
    if (idx == 4) return const Color(0xFF60A5FA);
    if (idx == 5) return const Color(0xFFC084FC);
    if (idx == 6) return CyberColors.cyan;
    if (idx == 7) return Colors.white;
    if (idx >= 8 && idx <= 15) return CyberColors.textMuted;

    if (idx >= 16 && idx <= 231) {
      final code = idx - 16;
      final r = ((code ~/ 36) * 51).clamp(0, 255);
      final g = (((code % 36) ~/ 6) * 51).clamp(0, 255);
      final b = ((code % 6) * 51).clamp(0, 255);
      return Color.fromRGBO(r, g, b, 1.0);
    }

    // 232..255: 灰階漸層
    final gray = (8 + (idx - 232) * 10).clamp(0, 255);
    return Color.fromRGBO(gray, gray, gray, 1.0);
  }

  /// 單純去除所有 ANSI Escape Codes
  static String stripAnsi(String text) {
    return text.replaceAll(_ansiRegex, '');
  }
}
