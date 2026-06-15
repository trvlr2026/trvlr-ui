import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF0D9488);
  static const primaryDark = Color(0xFF0F766E);
  static const accent = Color(0xFFF59E0B);
  static const surface = Color(0xFFF8FAFC);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const visited = Color(0xFF22C55E);
  static const unvisited = Color(0xFF94A3B8);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
  return base;
}
