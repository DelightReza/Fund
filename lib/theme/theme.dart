
import 'package:flutter/material.dart';
import 'colors.dart';

ThemeData get lightTheme {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: AppColors.indigo600,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFEEF2FF),
      onPrimaryContainer: const Color(0xFF1E1B4B),
      secondary: AppColors.emerald600,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.emerald100,
      onSecondaryContainer: const Color(0xFF064E3B),
      tertiary: AppColors.rose600,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.rose100,
      onTertiaryContainer: const Color(0xFF881337),
      background: AppColors.slate50,
      onBackground: AppColors.navy900,
      surface: Colors.white,
      onSurface: AppColors.navy900,
      surfaceVariant: AppColors.slate100,
      onSurfaceVariant: AppColors.slate600,
      outline: const Color(0xFFCBD5E1),
      outlineVariant: const Color(0xFFE2E8F0),
    ),
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.bold),
      // ... other sizes
    ),
  );
}

ThemeData get darkTheme {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: AppColors.indigoLight,
      onPrimary: AppColors.darkBg,
      primaryContainer: AppColors.navy800,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.emeraldLight,
      onSecondary: AppColors.darkBg,
      secondaryContainer: Color(0xFF064E3B),
      onSecondaryContainer: AppColors.emerald100,
      tertiary: AppColors.roseLight,
      onTertiary: AppColors.darkBg,
      tertiaryContainer: Color(0xFF881337),
      onTertiaryContainer: AppColors.rose100,
      background: AppColors.darkBg,
      onBackground: const Color(0xFFF1F5F9),
      surface: AppColors.darkSurface,
      onSurface: const Color(0xFFF1F5F9),
      surfaceVariant: AppColors.darkSurfaceVariant,
      onSurfaceVariant: const Color(0xFFCBD5E1),
      outline: const Color(0xFF475569),
      outlineVariant: const Color(0xFF334155),
    ),
    fontFamily: 'Roboto',
  );
}

