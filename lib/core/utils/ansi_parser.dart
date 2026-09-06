import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ANSI Escape Code 解析與著色過濾處理器
class AnsiParser {
  static final RegExp _ansiRegex = RegExp(r'\x1B\[(\??[0-9;]*)([a-zA-Z])');

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
        style: AppTheme.codeFont(
          color: baseColor,
          fontSize: fontSize,
        ),
      );
    }

    final spans = <InlineSpan>[];

    Color currentColor = baseColor;
    FontWeight currentWeight = FontWeight.normal;

    int lastIndex = 0;
    for (final match in _ansiRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        final segment = text.substring(lastIndex, match.start);
        spans.add(TextSpan(
          text: segment,
          style: AppTheme.codeFont(
            color: currentColor,
            fontSize: fontSize,
          ).copyWith(fontWeight: currentWeight),
        ));
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
          for (final part in parts) {
            final code = int.tryParse(part);
            if (code == null) continue;
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
          }
        }
      }
      // 非 'm' 之指令（如 \x1B[2K, \x1B[?25h 等游標控制碼）自動被乾淨過濾剔除

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: AppTheme.codeFont(
          color: currentColor,
          fontSize: fontSize,
        ).copyWith(fontWeight: currentWeight),
      ));
    }

    if (spans.isEmpty) {
      return TextSpan(
        text: text,
        style: AppTheme.codeFont(
          color: baseColor,
          fontSize: fontSize,
        ),
      );
    }

    return TextSpan(children: spans);
  }

  /// 單純去除所有 ANSI Escape Codes
  static String stripAnsi(String text) {
    return text.replaceAll(_ansiRegex, '');
  }
}
