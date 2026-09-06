import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CyberColors {
  CyberColors._();

  // Background & Surfaces
  static const Color background = Color(0xFF080C14);
  static const Color surface = Color(0xFF0F172A);
  static const Color surfaceElevated = Color(0xFF172338);
  static const Color card = Color(0xFF131D2E);
  static const Color cardElevated = Color(0xFF1E2B42);
  static const Color cardBorder = Color(0x3338BDF8);
  static const Color subtleBorder = Color(0x1FFFFFFF);

  // Neon & Cyber Accents
  static const Color cyan = Color(0xFF00E5FF);
  static const Color cyanGlow = Color(0x3300E5FF);
  static const Color emerald = Color(0xFF00E676);
  static const Color emeraldGlow = Color(0x3300E676);
  static const Color violet = Color(0xFFA855F7);
  static const Color violetGlow = Color(0x33A855F7);
  static const Color amber = Color(0xFFFFB300);
  static const Color amberGlow = Color(0x33FFB300);
  static const Color red = Color(0xFFFF3366);
  static const Color redGlow = Color(0x33FF3366);
  static const Color blue = Color(0xFF3B82F6);

  // Typography
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textCode = Color(0xFF38BDF8);

  // Terminal
  static const Color terminalBg = Color(0xFF05080E);
  static const Color terminalText = Color(0xFF4ADE80);
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CyberColors.background,
      primaryColor: CyberColors.cyan,
      colorScheme: const ColorScheme.dark(
        primary: CyberColors.cyan,
        secondary: CyberColors.emerald,
        surface: CyberColors.surface,
        error: CyberColors.red,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: CyberColors.textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: CyberColors.background,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: CyberColors.textPrimary),
        titleTextStyle: TextStyle(
          color: CyberColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: CyberColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: CyberColors.subtleBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: CyberColors.cardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: CyberColors.cardBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CyberColors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: const TextStyle(color: CyberColors.textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CyberColors.subtleBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CyberColors.subtleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CyberColors.cyan, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CyberColors.cyan,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.outfit(
          color: CyberColors.textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.outfit(
          color: CyberColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.outfit(
          color: CyberColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.outfit(
          color: CyberColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          color: CyberColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          color: CyberColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          color: CyberColors.textMuted,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static TextStyle codeFont({
    Color color = CyberColors.textCode,
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return GoogleFonts.jetBrainsMono(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }
}
