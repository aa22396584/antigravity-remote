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

    test('parses 24-bit TrueColor and 256-color sequences', () {
      // 24-bit RGB: 38;2;255;128;0
      const trueColorInput = '\x1B[38;2;255;128;0mOrange\x1B[0m';
      final span = AnsiParser.parseToSpan(trueColorInput);
      expect(span.children, isNotNull);
      final orangeSpan = span.children![0] as TextSpan;
      expect(orangeSpan.text, 'Orange');
      expect(orangeSpan.style?.color, const Color.fromRGBO(255, 128, 0, 1.0));

      // 256-color: 38;5;1 (red)
      const color256Input = '\x1B[38;5;1mRed256\x1B[0m';
      final span256 = AnsiParser.parseToSpan(color256Input);
      expect(span256.children, isNotNull);
      final redSpan = span256.children![0] as TextSpan;
      expect(redSpan.text, 'Red256');
      expect(redSpan.style?.color, CyberColors.red);
    });

    test('filters OSC window title sequences and carriage returns', () {
      const input = '\x1B]0;Terminal: bash\x07Hello Terminal\r\n';
      final clean = AnsiParser.stripAnsi(input);
      expect(clean, 'Hello Terminal\r\n');

      final span = AnsiParser.parseToSpan(input);
      expect(span.text != null || span.children != null, isTrue);
      final combinedText =
          span.text ?? span.children!.map((e) => (e as TextSpan).text).join();
      expect(combinedText.contains('Terminal: bash'), isFalse);
      expect(combinedText.contains('Hello Terminal'), isTrue);
    });
  });
}
