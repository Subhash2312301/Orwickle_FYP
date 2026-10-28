import 'package:flutter/material.dart';

/// Orwickle look and feel (Material 3), from the brand sheet: indigo primary, purple secondary,
/// teal accent, light grey background. All screens take colours and text styles from here.
class AppTheme {
  const AppTheme._();

  static const Color brand = Color(0xFF6366F1); // indigo, for gradients and large shapes
  static const Color brandDeep = Color(0xFF4F46E5); // buttons and links: white text on it is 6.3:1
  static const Color brandSecondary = Color(0xFF8B5CF6); // purple
  static const Color accent = Color(0xFF06B6D4); // teal, decoration only (too light for text)
  static const Color accentText = Color(0xFF0E7490); // teal that is readable as text
  static const Color background = Color(0xFFF3F4F6);
  static const Color ink = Color(0xFF111827);
  static const Color darkBackground = Color(0xFF0B1020);
  static const Color darkSurface = Color(0xFF151B2E);

  /// Brand gradient for the splash, welcome header and home banner (not for whole screens).
  static const LinearGradient gradient = LinearGradient(
    colors: [brand, brandSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final base = ColorScheme.fromSeed(seedColor: brand, brightness: brightness);
    final colors = isLight
        ? base.copyWith(
            primary: brandDeep,
            onPrimary: Colors.white,
            secondary: brandSecondary,
            tertiary: accentText,
            surface: Colors.white,
            onSurface: ink,
          )
        : base.copyWith(
            primary: const Color(0xFFA5B4FC),
            onPrimary: const Color(0xFF1E1B4B),
            secondary: const Color(0xFFC4B5FD),
            tertiary: const Color(0xFF67E8F9),
            surface: darkSurface,
          );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md));
    final text = Typography.material2021(platform: TargetPlatform.android).black
        .apply(bodyColor: colors.onSurface, displayColor: colors.onSurface);
    return ThemeData(
      colorScheme: colors,
      useMaterial3: true,
      extensions: [isLight ? StatusColors.light : StatusColors.dark],
      scaffoldBackgroundColor: isLight ? background : darkBackground,
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? background : darkBackground,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colors.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
        filled: true,
        fillColor: colors.surface,
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
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill))),
    );
  }
}

/// Spacing scale: use these instead of loose numbers so screens line up.
class Gaps {
  const Gaps._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radius scale.
class Radii {
  const Radii._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 20;
}

/// Meaning colours for statuses, readable as text in both light and dark mode:
/// success = approved / live, warning = pending / draft, danger = rejected, info = in review.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({required this.success, required this.warning, required this.danger, required this.info});

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  static const light = StatusColors(
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    danger: Color(0xFFB91C1C),
    info: AppTheme.accentText,
  );

  static const dark = StatusColors(
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    info: Color(0xFF67E8F9),
  );

  static StatusColors of(BuildContext context) => Theme.of(context).extension<StatusColors>() ?? light;

  @override
  StatusColors copyWith({Color? success, Color? warning, Color? danger, Color? info}) => StatusColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    info: info ?? this.info,
  );

  @override
  StatusColors lerp(covariant StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}
