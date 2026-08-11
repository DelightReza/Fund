import 'package:flutter/material.dart';

import 'colors.dart';

ThemeData get lightTheme {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.seed, brightness: Brightness.light);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  );
}

ThemeData get darkTheme {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.seed, brightness: Brightness.dark);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  );
}
