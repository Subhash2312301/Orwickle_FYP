import 'package:flutter/material.dart';

/// Orwickle look and feel (Material 3), from the brand sheet: indigo primary, purple secondary,
/// teal accent, light grey background. All screens take colours and text styles from here.
class AppTheme {
  const AppTheme._();

  static const Color brand = Color(0xFF6366F1); // indigo
  static const Color brandSecondary = Color(0xFF8B5CF6); // purple
  static const Color accent = Color(0xFF06B6D4); // teal
  static const Color background = Color(0xFFF3F4F6);
  static const Color ink = Color(0xFF111827);

  /// Brand gradient for headers and the welcome screen.
  static const LinearGradient gradient = LinearGradient(
    colors: [brand, brandSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    var colors = ColorScheme.fromSeed(seedColor: brand, brightness: brightness);
    if (isLight) {
      colors = colors.copyWith(
        primary: brand,
        secondary: brandSecondary,
        tertiary: accent,
        surface: Colors.white,
        onSurface: ink,
      );
    }
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return ThemeData(
      colorScheme: colors,
      useMaterial3: true,
      scaffoldBackgroundColor: isLight ? background : null,
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? background : null,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colors.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isLight ? Colors.white : null,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: shape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: shape)),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    );
  }
}
