import 'package:flutter/material.dart';

/// Orwickle look and feel (Material 3). All screens take colours and text styles from here.
class AppTheme {
  const AppTheme._();

  static const Color brand = Color(0xFF1F4E79); // deep blue: trust, finance

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colors = ColorScheme.fromSeed(seedColor: brand, brightness: brightness);
    return ThemeData(
      colorScheme: colors,
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
