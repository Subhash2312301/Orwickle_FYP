import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale. Sora (geometric, characterful) for display, headline and large titles;
/// Inter (very readable at small sizes) for everything else. Both are bundled in
/// assets/google_fonts, so nothing is downloaded at runtime.
class AppTypography {
  const AppTypography._();

  static TextStyle _sora(double size, FontWeight weight, double height, {double spacing = 0}) =>
      GoogleFonts.sora(fontSize: size, fontWeight: weight, height: height / size, letterSpacing: spacing);

  static TextStyle _inter(double size, FontWeight weight, double height, {double spacing = 0}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, height: height / size, letterSpacing: spacing);

  static TextTheme textTheme(Color onSurface, Color muted) {
    final base = TextTheme(
      displayLarge: _sora(44, FontWeight.w800, 50, spacing: -1.2),
      displayMedium: _sora(36, FontWeight.w800, 42, spacing: -1),
      displaySmall: _sora(30, FontWeight.w700, 36, spacing: -0.8),
      headlineLarge: _sora(28, FontWeight.w700, 34, spacing: -0.6),
      headlineMedium: _sora(24, FontWeight.w700, 30, spacing: -0.4),
      headlineSmall: _sora(20, FontWeight.w700, 26, spacing: -0.2),
      titleLarge: _sora(18, FontWeight.w600, 24, spacing: -0.1),
      titleMedium: _inter(16, FontWeight.w600, 22),
      titleSmall: _inter(14, FontWeight.w600, 20),
      bodyLarge: _inter(16, FontWeight.w400, 24),
      bodyMedium: _inter(14, FontWeight.w400, 20),
      bodySmall: _inter(12.5, FontWeight.w400, 17),
      labelLarge: _inter(14, FontWeight.w600, 20, spacing: 0.1),
      labelMedium: _inter(12, FontWeight.w600, 16, spacing: 0.2),
      labelSmall: _inter(11, FontWeight.w600, 14, spacing: 0.4),
    );
    return base
        .apply(bodyColor: onSurface, displayColor: onSurface)
        .copyWith(bodySmall: base.bodySmall!.copyWith(color: muted));
  }
}

/// Extra text styles that are not part of Material's [TextTheme].
extension AppTextStyles on TextTheme {
  /// Money, equity and counts: tabular figures so digits line up and do not jump when they animate.
  TextStyle numeric({double size = 18, FontWeight weight = FontWeight.w700}) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    height: 1.2,
    letterSpacing: -0.2,
    color: titleMedium?.color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Small capitals label above a section ("PUBLIC PREVIEW").
  TextStyle get overline => labelSmall!.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700);
}
