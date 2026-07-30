import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const steamNavy = Color(0xFF171A21);
  static const steamDark = Color(0xFF1B2838);
  static const steamMid = Color(0xFF2A475E);
  static const steamAccent = Color(0xFF66C0F4);
  static const steamGreen = Color(0xFF5BA32B);
  static const steamText = Color(0xFFC7D5E0);
  static const steamMuted = Color(0xFF8F98A0);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: steamNavy,
      colorScheme: const ColorScheme.dark(
        primary: steamAccent,
        secondary: steamGreen,
        surface: steamDark,
        onPrimary: steamNavy,
        onSurface: steamText,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.barlowTextTheme(base.textTheme).apply(
        bodyColor: steamText,
        displayColor: steamText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: steamText,
      ),
      cardTheme: CardThemeData(
        color: steamDark.withValues(alpha: 0.85),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: steamMid.withValues(alpha: 0.6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: steamAccent,
          foregroundColor: steamNavy,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: steamDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: steamMid.withValues(alpha: 0.8)),
        ),
      ),
    );
  }
}
