import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide dark theme matching the ScholarLens web design.
class AppTheme {
  AppTheme._();

  // ─── Colors ────────────────────────────────────────
  static const Color background = Color(0xFF05070A); // Obsidian
  static const Color surface = Color(0xFF0D1117);
  static const Color surfaceVariant = Color(0xFF161B22);
  static const Color glassBorder = Color(0x33FFFFFF); // Iridescent/Glass border
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textDim = Color(0xFF8B949E);
  
  // New Aurora Palette
  static const Color accentTeal = Color(0xFF00F5D4);
  static const Color accentSapphire = Color(0xFF4361EE);
  static const Color accentViolet = Color(0xFF7209B7);
  static const Color accentEnd = Color(0xFFE052A0);

  static const Color accent = accentSapphire;

  static LinearGradient auroraGradient = const LinearGradient(
    colors: [accentTeal, accentSapphire, accentViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient glassGradient = LinearGradient(
    colors: [
      Colors.white.withValues(alpha: 0.1),
      Colors.white.withValues(alpha: 0.05),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Theme Data ────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accentSapphire,
      colorScheme: const ColorScheme.dark(
        primary: accentSapphire,
        secondary: accentTeal,
        tertiary: accentViolet,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.outfitTextTheme( // Switched to Outfit
        ThemeData.dark().textTheme.copyWith(
              headlineLarge: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -1,
              ),
              headlineMedium: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              titleLarge: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
              titleMedium: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
              bodyLarge: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: textPrimary,
              ),
              bodyMedium: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: textDim,
              ),
              bodySmall: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: textDim,
              ),
              labelMedium: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textDim,
                letterSpacing: 0.5,
              ),
            ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Increased radius
          side: const BorderSide(color: glassBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentTeal, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textDim, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        selectedColor: accentSapphire,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: glassBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dividerColor: glassBorder,
    );
  }
}
