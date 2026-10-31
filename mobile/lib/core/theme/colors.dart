import 'package:flutter/material.dart';

/// Raw palette ("ink and cobalt"). Only the theme files use these directly;
/// widgets read colours from [ColorScheme] or [AppColors].
class Palette {
  const Palette._();

  // ink: the navy base, for dark surfaces and text
  static const ink950 = Color(0xFF070C17);
  static const ink900 = Color(0xFF0B1220);
  static const ink800 = Color(0xFF121A2B);
  static const ink700 = Color(0xFF1A2438);
  static const ink600 = Color(0xFF26324A);

  // slate: neutral greys with a cool tint
  static const slate600 = Color(0xFF4B5468);
  static const slate500 = Color(0xFF5B6478);
  static const slate400 = Color(0xFF8A93A6);
  static const slate300 = Color(0xFFC5CBD6);
  static const slate200 = Color(0xFFE2E6EE);
  static const slate100 = Color(0xFFEEF1F6);
  static const paper = Color(0xFFF6F7FB);
  static const white = Color(0xFFFFFFFF);

  // cobalt: the one primary accent (trust). White on cobalt600 is 7:1.
  static const cobalt700 = Color(0xFF1B37B8);
  static const cobalt600 = Color(0xFF2448E0);
  static const cobalt400 = Color(0xFF7B97FF);
  static const cobalt200 = Color(0xFFC9D5FF);
  static const cobalt100 = Color(0xFFE8EDFF);
  static const cobalt900 = Color(0xFF14204D);

  // listing types
  static const amber500 = Color(0xFFF08C1A); // funding, decoration
  static const amber700 = Color(0xFFA8470A); // funding, text on light (5.9:1)
  static const amber300 = Color(0xFFFFB067); // funding, text on dark
  static const amber50 = Color(0xFFFFF1E3);
  static const amber950 = Color(0xFF3A2210);

  static const teal500 = Color(0xFF12B5AD); // sale, decoration
  static const teal700 = Color(0xFF0B7470); // sale, text on light (5.4:1)
  static const teal300 = Color(0xFF4FD8CF); // sale, text on dark
  static const teal50 = Color(0xFFE0F6F4);
  static const teal950 = Color(0xFF0E2E2D);

  // statuses
  static const gold700 = Color(0xFF8A5B00);
  static const gold300 = Color(0xFFF5C451);
  static const gold50 = Color(0xFFFFF6DB);
  static const gold950 = Color(0xFF33290F);

  static const green700 = Color(0xFF157F3C);
  static const green300 = Color(0xFF4ADE80);
  static const green50 = Color(0xFFE3F6EA);
  static const green950 = Color(0xFF0F2C1A);

  static const red700 = Color(0xFFC0262D);
  static const red300 = Color(0xFFFF8A8A);
  static const red50 = Color(0xFFFDE8E8);
  static const red950 = Color(0xFF3A1416);

  static const violet700 = Color(0xFF6D3FD1);
  static const violet300 = Color(0xFFB79CFF);
  static const violet50 = Color(0xFFF0EAFF);
  static const violet950 = Color(0xFF261A45);
}

/// A meaning colour: [fg] is readable as text and icons on normal surfaces and on [bg];
/// [bg] is the soft fill behind chips and banners.
@immutable
class Tone {
  const Tone(this.fg, this.bg);

  final Color fg;
  final Color bg;

  static Tone lerp(Tone a, Tone b, double t) => Tone(Color.lerp(a.fg, b.fg, t)!, Color.lerp(a.bg, b.bg, t)!);
}

/// Orwickle's own colours, beyond Material's [ColorScheme]: listing types, statuses,
/// the verified badge and a few surface roles.
///
///     final colors = AppColors.of(context);
///     Icon(Icons.trending_up, color: colors.funding.fg);
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.funding,
    required this.sale,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.expired,
    required this.countered,
    required this.verified,
    required this.info,
    required this.canvas,
    required this.border,
    required this.borderStrong,
    required this.textMuted,
    required this.hero,
    required this.onHero,
    required this.skeleton,
    required this.shadow,
  });

  final Tone funding; // "Seeking Funding"
  final Tone sale; // "Available for Purchase"
  final Tone pending;
  final Tone approved;
  final Tone rejected;
  final Tone expired;
  final Tone countered;
  final Tone verified;
  final Tone info;

  final Color canvas; // page background
  final Color border; // card and input outlines
  final Color borderStrong;
  final Color textMuted; // secondary text, AA on canvas and surface
  final Color hero; // always-dark header surfaces (splash, stats header)
  final Color onHero;
  final Color skeleton; // loading placeholder blocks
  final Color shadow;

  /// Old names, used by screens not yet moved to the statuses above.
  Color get success => approved.fg;
  Color get warning => pending.fg;
  Color get danger => rejected.fg;

  Tone listingType({required bool isFunding}) => isFunding ? funding : sale;

  static const light = AppColors(
    funding: Tone(Palette.amber700, Palette.amber50),
    sale: Tone(Palette.teal700, Palette.teal50),
    pending: Tone(Palette.gold700, Palette.gold50),
    approved: Tone(Palette.green700, Palette.green50),
    rejected: Tone(Palette.red700, Palette.red50),
    expired: Tone(Palette.slate500, Palette.slate100),
    countered: Tone(Palette.violet700, Palette.violet50),
    verified: Tone(Palette.cobalt600, Palette.cobalt100),
    info: Tone(Palette.cobalt600, Palette.cobalt100),
    canvas: Palette.paper,
    border: Palette.slate200,
    borderStrong: Palette.slate300,
    textMuted: Palette.slate500,
    hero: Palette.ink900,
    onHero: Palette.white,
    skeleton: Palette.slate200,
    shadow: Palette.ink900,
  );

  static const dark = AppColors(
    funding: Tone(Palette.amber300, Palette.amber950),
    sale: Tone(Palette.teal300, Palette.teal950),
    pending: Tone(Palette.gold300, Palette.gold950),
    approved: Tone(Palette.green300, Palette.green950),
    rejected: Tone(Palette.red300, Palette.red950),
    expired: Tone(Palette.slate400, Palette.ink700),
    countered: Tone(Palette.violet300, Palette.violet950),
    verified: Tone(Palette.cobalt400, Palette.cobalt900),
    info: Tone(Palette.cobalt400, Palette.cobalt900),
    canvas: Palette.ink950,
    border: Palette.ink600,
    borderStrong: Palette.slate600,
    textMuted: Palette.slate400,
    hero: Palette.ink800,
    onHero: Palette.white,
    skeleton: Palette.ink700,
    shadow: Palette.ink950,
  );

  static AppColors of(BuildContext context) => Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith({Tone? funding, Tone? sale}) => AppColors(
    funding: funding ?? this.funding,
    sale: sale ?? this.sale,
    pending: pending,
    approved: approved,
    rejected: rejected,
    expired: expired,
    countered: countered,
    verified: verified,
    info: info,
    canvas: canvas,
    border: border,
    borderStrong: borderStrong,
    textMuted: textMuted,
    hero: hero,
    onHero: onHero,
    skeleton: skeleton,
    shadow: shadow,
  );

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      funding: Tone.lerp(funding, other.funding, t),
      sale: Tone.lerp(sale, other.sale, t),
      pending: Tone.lerp(pending, other.pending, t),
      approved: Tone.lerp(approved, other.approved, t),
      rejected: Tone.lerp(rejected, other.rejected, t),
      expired: Tone.lerp(expired, other.expired, t),
      countered: Tone.lerp(countered, other.countered, t),
      verified: Tone.lerp(verified, other.verified, t),
      info: Tone.lerp(info, other.info, t),
      canvas: c(canvas, other.canvas),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      textMuted: c(textMuted, other.textMuted),
      hero: c(hero, other.hero),
      onHero: c(onHero, other.onHero),
      skeleton: c(skeleton, other.skeleton),
      shadow: c(shadow, other.shadow),
    );
  }
}
