import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Color Palette (Strava Inspired) ──
  static const Color primary = Color(0xFFFC4C02); // Strava Orange
  static const Color primaryDark = Color(0xFFE34402);
  static const Color accent = Color(0xFFFF6B00);
  
  static const Color background = Color(0xFF121212); // Deep dark background
  static const Color surface = Color(0xFF1E1E1E);    // Slightly lighter for cards
  static const Color surfaceLight = Color(0xFF2C2C2C);
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color textMuted = Color(0xFF6E6E6E);
  
  static const Color danger = Color(0xFFFF4757);
  static const Color success = Color(0xFF2ED573);
  static const Color warning = Color(0xFFFFAB00);

  // ── HR Zone Colors ──
  static const Color hrZone1 = Color(0xFF90CAF9); // Rest (< 60% max)
  static const Color hrZone2 = Color(0xFF4CAF50); // Easy (60-70%)
  static const Color hrZone3 = Color(0xFFFFEB3B); // Moderate (70-80%)
  static const Color hrZone4 = Color(0xFFFF9800); // Hard (80-90%)
  static const Color hrZone5 = Color(0xFFF44336); // Max (90%+)

  /// Get HR zone color based on percentage of max HR.
  static Color hrZoneColor(int hr, int maxHR) {
    if (maxHR <= 0 || hr <= 0) return textMuted;
    final pct = hr / maxHR;
    if (pct < 0.6) return hrZone1;
    if (pct < 0.7) return hrZone2;
    if (pct < 0.8) return hrZone3;
    if (pct < 0.9) return hrZone4;
    return hrZone5;
  }

  /// Get HR zone name.
  static String hrZoneName(int hr, int maxHR) {
    if (maxHR <= 0 || hr <= 0) return '--';
    final pct = hr / maxHR;
    if (pct < 0.6) return 'REST';
    if (pct < 0.7) return 'EASY';
    if (pct < 0.8) return 'MODERATE';
    if (pct < 0.9) return 'HARD';
    return 'MAX';
  }

  // ── Glassmorphic decoration ──
  static BoxDecoration glassmorphicDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: surface.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.08),
      ),
    );
  }

  // ── Theme Data ──
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: danger,
      ),
      textTheme: TextTheme(
        // Hero metric only (e.g., HR in ring) — 72px
        displayLarge: GoogleFonts.barlowCondensed(
          fontSize: 72,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -1.0,
        ),
        // Primary metrics (time, distance) — 48px
        displayMedium: GoogleFonts.barlowCondensed(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        // Secondary metrics (pace, calories) — 32px
        displaySmall: GoogleFonts.barlowCondensed(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        // Clean labels for metrics (e.g., "HEART RATE", "DISTANCE")
        labelLarge: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textSecondary,
          letterSpacing: 1.2,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textMuted,
          letterSpacing: 1.0,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 1.0,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: surfaceLight, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: textSecondary),
    );
  }
}
