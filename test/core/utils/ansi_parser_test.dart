import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/core/theme/app_theme.dart';
import 'package:antigravity_remote/core/utils/ansi_parser.dart';

import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('AnsiParser Tests', () {
    test('plain text returns single TextSpan without change', () {
      final span = AnsiParser.parseToSpan('Hello World');
      expect(span.text, 'Hello World');
    });

    test('stripAnsi removes escape codes and returns clean text', () {
      const input = '\x1B[32mPASS\x1B[0m: \x1B[1mtest_name\x1B[0m\x1B[2K';
      final clean = AnsiParser.stripAnsi(input);
      expect(clean, 'PASS: test_name');
    });

    test('parses ANSI colors and styles into TextSpan children', () {
      const input = '\x1B[32mSuccess\x1B[0m and \x1B[31mError\x1B[0m';
      final span = AnsiParser.parseToSpan(input);

      expect(span.children, isNotNull);
      expect(span.children!.length, 3);

      final greenPart = span.children![0] as TextSpan;
      expect(greenPart.text, 'Success');
      expect(greenPart.style?.color, CyberColors.emerald);

      final plainPart = span.children![1] as TextSpan;
      expect(plainPart.text, ' and ');
      expect(plainPart.style?.color, CyberColors.terminalText);

      final redPart = span.children![2] as TextSpan;
      expect(redPart.text, 'Error');
      expect(redPart.style?.color, CyberColors.red);
    });

    test('parses bold weight and filters control codes', () {
      const input = '\x1B[1;36mBoldCyan\x1B[0m\x1B[?25hNormal';
      final span = AnsiParser.parseToSpan(input);

      expect(span.children, isNotNull);
      expect(span.children!.length, 2);

      final boldCyan = span.children![0] as TextSpan;
      expect(boldCyan.text, 'BoldCyan');
      expect(boldCyan.style?.color, CyberColors.cyan);
      expect(boldCyan.style?.fontWeight, FontWeight.bold);

      final normal = span.children![1] as TextSpan;
      expect(normal.text, 'Normal');
      expect(normal.style?.fontWeight, FontWeight.normal);
    });
  });
}
