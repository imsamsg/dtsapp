import 'package:flutter/material.dart';

/// Palette sampled from designs/login.png and designs/home.png (DTS brand green).
class AppColors {
  AppColors._();

  static const primary = Color(0xFF0E6251); // teal-green CTA / brand accent
  static const primaryDark = Color(0xFF0B3D2E); // sidebar / gradient background
  static const surfaceTint = Color(0xFFF3F7F5); // light card-on-tinted-background
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
