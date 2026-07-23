import 'package:flutter/material.dart';

/// Palette sourced from designs/appdesign.png's brand color swatches.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF0F766E); // teal-green CTA / brand accent
  static const primaryDark = Color(0xFF0B4F49); // gradient header dark end (manual shade; not in the swatch sheet)
  static const accent = Color(0xFF14BBA6); // secondary accent, gradient mid-tone
  static const surfaceTint = Color(0xFFF0FDF4); // light card-on-tinted-background
  static const danger = Color(0xFFEF4444); // error state
  static const warning = Color(0xFFF59E0B); // low-stock badge
  static const neutral = Color(0xFF64748B); // inactive-status badge, secondary text
}

final ThemeData appThemeLight = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
  scaffoldBackgroundColor: AppColors.surfaceTint,
  appBarTheme: const AppBarTheme(centerTitle: false, backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size.fromHeight(48)),
  ),
);
