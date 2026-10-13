import 'package:flutter/material.dart';

class AppTheme {
  // Vibrant Modern Fintech Color Tokens
  static const primaryIndigo = Color(0xFF4F46E5); // Indigo 600
  static const primaryIndigoDark = Color(0xFF6366F1); // Indigo 500
  static const royalBlue = Color(0xFF2563EB); // Blue 600
  static const emeraldGreen =
      Color(0xFF10B981); // Emerald 500 (Credits / Deposits / Surplus)
  static const emeraldDark = Color(0xFF059669); // Emerald 600
  static const roseCrimson =
      Color(0xFFF43F5E); // Rose 500 (Debits / Expenses / Owing)
  static const roseDark = Color(0xFFE11D48); // Rose 600
  static const electricViolet =
      Color(0xFF8B5CF6); // Violet 500 (Transfers / Settlements)
  static const violetDark = Color(0xFF7C3AED); // Violet 600
  static const amberSun =
      Color(0xFFF59E0B); // Amber 500 (Warnings / Category Accent)
  static const cyanAqua = Color(0xFF06B6D4); // Cyan 500 (Utility / Fresh)
  static const slateMuted = Color(0xFF64748B); // Slate 500

  // Gradients for Modern Cards & Badges
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E1B4B), // Deep Indigo 950
      Color(0xFF312E81), // Indigo 900
      Color(0xFF4338CA), // Indigo 700
    ],
  );

  static const LinearGradient deficitGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4C0519), // Deep Rose 950
      Color(0xFF881337), // Rose 900
      Color(0xFFBE123C), // Rose 700
    ],
  );

  static const LinearGradient roseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFBE123C),
      Color(0xFFE11D48),
      Color(0xFFF43F5E),
    ],
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF065F46),
      Color(0xFF059669),
      Color(0xFF10B981),
    ],
  );

  static const LinearGradient violetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4C1D95),
      Color(0xFF6D28D9),
      Color(0xFF8B5CF6),
    ],
  );

  static const LinearGradient amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF78350F),
      Color(0xFFD97706),
      Color(0xFFF59E0B),
    ],
  );

  static const LinearGradient cyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF164E63),
      Color(0xFF0891B2),
      Color(0xFF06B6D4),
    ],
  );

  static const LinearGradient royalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E3A8A),
      Color(0xFF2563EB),
      Color(0xFF3B82F6),
    ],
  );

  static const darkBackground = Color(0xFF0B1120);
  static const darkSurface = Color(0xFF151F32);
  static const darkCard = Color(0xFF1E293B);
  static const darkBorder = Color(0xFF2E3D52);

  /// Helper to return a consistent vibrant brand color for each category ID
  static Color getCategoryColor(String categoryId) {
    final lower = categoryId.toLowerCase();
    if (lower.contains('food') ||
        lower.contains('eat') ||
        lower.contains('meal') ||
        lower.contains('cook')) {
      return amberSun;
    }
    if (lower.contains('water') ||
        lower.contains('drink') ||
        lower.contains('aqua')) {
      return cyanAqua;
    }
    if (lower.contains('rent') ||
        lower.contains('room') ||
        lower.contains('house')) {
      return electricViolet;
    }
    if (lower.contains('wifi') ||
        lower.contains('net') ||
        lower.contains('bill') ||
        lower.contains('electric')) {
      return royalBlue;
    }
    if (lower.contains('grocery') ||
        lower.contains('market') ||
        lower.contains('veg')) {
      return emeraldGreen;
    }
    if (lower.contains('clean') ||
        lower.contains('maid') ||
        lower.contains('serv')) {
      return const Color(0xFF14B8A6); // Teal
    }
    if (lower.contains('travel') ||
        lower.contains('cab') ||
        lower.contains('fuel')) {
      return const Color(0xFFF97316); // Orange
    }
    if (lower.contains('fun') ||
        lower.contains('party') ||
        lower.contains('movie')) {
      return const Color(0xFFEC4899); // Pink
    }
    return primaryIndigo;
  }

  /// Helper to return a vibrant gradient for category hero cards and avatar backgrounds
  static LinearGradient getCategoryGradient(String categoryId) {
    final lower = categoryId.toLowerCase();
    if (lower.contains('food') ||
        lower.contains('eat') ||
        lower.contains('meal')) {
      return amberGradient;
    }
    if (lower.contains('water') ||
        lower.contains('drink') ||
        lower.contains('aqua')) {
      return cyanGradient;
    }
    if (lower.contains('rent') ||
        lower.contains('room') ||
        lower.contains('house')) {
      return violetGradient;
    }
    if (lower.contains('grocery') || lower.contains('market')) {
      return emeraldGradient;
    }
    if (lower.contains('wifi') ||
        lower.contains('net') ||
        lower.contains('bill')) {
      return royalGradient;
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF7C3AED)],
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryIndigo,
        brightness: Brightness.light,
        primary: primaryIndigo,
        secondary: emeraldGreen,
        tertiary: electricViolet,
        error: roseCrimson,
        surface: const Color(0xFFF8FAFC),
      ),
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      cardTheme: CardThemeData(
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        color: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryIndigo, width: 2),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryIndigoDark,
        brightness: Brightness.dark,
        primary: primaryIndigoDark,
        secondary: const Color(0xFF34D399),
        tertiary: const Color(0xFFA78BFA),
        error: const Color(0xFFFB7185),
        surface: darkSurface,
      ),
      scaffoldBackgroundColor: darkBackground,
      cardTheme: CardThemeData(
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        color: darkCard,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF475569)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryIndigoDark, width: 2),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryIndigoDark,
        foregroundColor: Colors.white,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
