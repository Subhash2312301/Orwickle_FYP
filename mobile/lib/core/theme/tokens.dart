import 'package:flutter/material.dart';

/// Design tokens: the only place where raw sizes, durations and curves live.
/// Screens and widgets use these names, never loose numbers.

/// Spacing scale (4-point grid).
class Gaps {
  const Gaps._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page padding on phones.
  static const double page = 20;
}

/// Corner radius scale.
class Radii {
  const Radii._();

  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double pill = 999;
}

/// Icon sizes.
class IconSizes {
  const IconSizes._();

  static const double xs = 14;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double hero = 48;
}

/// Fixed component sizes.
class Sizes {
  const Sizes._();

  /// Minimum touch target (Material and WCAG guidance).
  static const double tapTarget = 48;
  static const double buttonHeight = 52;
  static const double buttonHeightCompact = 40;
  static const double inputHeight = 56;
  static const double navBarHeight = 72;
  static const double hairline = 1;
  static const double focusRing = 2;

  /// Readable width for forms and single-column content on tablets.
  static const double maxFormWidth = 480;
  static const double maxContentWidth = 640;

  /// Lists switch to two columns from this width.
  static const double twoColumnBreakpoint = 720;
}

/// Shadow scale. Kept soft: borders do most of the separating, shadows only lift.
class Elevations {
  const Elevations._();

  static List<BoxShadow> none = const [];

  static List<BoxShadow> sm(Color shadow) => [
    BoxShadow(color: shadow.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> md(Color shadow) => [
    BoxShadow(color: shadow.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6)),
    BoxShadow(color: shadow.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> lg(Color shadow) => [
    BoxShadow(color: shadow.withValues(alpha: 0.14), blurRadius: 32, offset: const Offset(0, 12)),
  ];

  /// Soft coloured glow around a focused field or a selected card.
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 0, spreadRadius: 4),
  ];
}

/// Animation durations and curves.
class Motion {
  const Motion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// Delay between items of a staggered list entrance.
  static const Duration stagger = Duration(milliseconds: 45);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve decelerate = Curves.easeOutQuart;

  /// Button press scale.
  static const double pressScale = 0.97;

  /// True when the user asked the system to reduce motion; animations should then be skipped.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero when motion is reduced.
  static Duration of(BuildContext context, Duration duration) => reduced(context) ? Duration.zero : duration;
}
