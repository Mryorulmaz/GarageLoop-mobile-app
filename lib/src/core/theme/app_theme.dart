import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Brand colors
  static const Color primaryNavy = Color(0xFF1A237E); // Lacivert
  static const Color accentOrange = Color(0xFFFF8C00);

  // Light theme
  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryNavy,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      );
}


