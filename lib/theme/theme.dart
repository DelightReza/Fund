import 'package:flutter/material.dart';
import 'colors.dart';

ThemeData get lightTheme {
  final scheme = const ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.indigo600,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFEEF2FF),
    onPrimaryContainer: Color(0xFF1E1B4B),
    secondary: AppColors.emerald600,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.emerald100,
    onSecondaryContainer: Color(0xFF064E3B),
    tertiary: AppColors.rose600,
    onTertiary: Colors.white,
    tertiaryContainer: AppColors.rose100,
    onTertiaryContainer: Color(0xFF881337),
    background: AppColors.slate50,
    onBackground: AppColors.navy900,
    surface: Colors.white,
    onSurface: AppColors.navy900,
    surfaceVariant: AppColors.slate100,
    onSurfaceVariant: AppColors.slate600,
    outline: Color(0xFFCBD5E1),
    outlineVariant: Color(0xFFE2E8F0),
    error: AppColors.rose600,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.background,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: scheme.background,
      surfaceTintColor: scheme.primary,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: scheme.onBackground,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
      color: scheme.surface,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 3,
      highlightElevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 8,
      height: 72,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationBarDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: scheme.primary);
        }
        return IconThemeData(color: scheme.onSurfaceVariant);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(color: scheme.primary, fontWeight: FontWeight.bold, fontSize: 12);
        }
        return TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.normal, fontSize: 12);
      }),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButtonStyle.fromCutOffPath(
        path: Path(),
        backgroundColor: scheme.surfaceVariant,
      ),
    ),
  );
}

ThemeData get darkTheme {
  final scheme = const ColorScheme(
    brightness: Brightness.dark,
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
    onBackground: Color(0xFFF1F5F9),
    surface: AppColors.darkSurface,
    onSurface: Color(0xFFF1F5F9),
    surfaceVariant: AppColors.darkSurfaceVariant,
    onSurfaceVariant: Color(0xFFCBD5E1),
    outline: Color(0xFF475569),
    outlineVariant: Color(0xFF334155),
    error: AppColors.roseLight,
    onError: AppColors.darkBg,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.background,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: scheme.background,
      surfaceTintColor: scheme.primary,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: scheme.onBackground,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
      color: scheme.surface,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 3,
      highlightElevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 8,
      height: 72,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationBarDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: scheme.primary);
        }
        return IconThemeData(color: scheme.onSurfaceVariant);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(color: scheme.primary, fontWeight: FontWeight.bold, fontSize: 12);
        }
        return TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.normal, fontSize: 12);
      }),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
    ),
  );
}
