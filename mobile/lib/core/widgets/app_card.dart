import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_button.dart';
import 'chips.dart';

enum AppCardVariant { outlined, elevated, tinted }

/// Surface for grouped content. Tappable when [onTap] is set (ink ripple and press scale).
///
/// * outlined (default): white card with a hairline border.
/// * elevated: no border, soft shadow; for content that floats over a header.
/// * tinted: the soft fill of [role]; for callouts such as the confidential section.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Gaps.lg),
    this.variant = AppCardVariant.outlined,
    this.role = ToneRole.info,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final AppCardVariant variant;

  /// Colour of a tinted card.
  final ToneRole role;

  /// Overrides the border, e.g. to highlight the current item.
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final app = AppColors.of(context);
    final tone = role.resolve(context);
    final radius = BorderRadius.circular(Radii.lg);

    final (fill, side) = switch (variant) {
      AppCardVariant.outlined => (colors.surface, BorderSide(color: borderColor ?? app.border)),
      AppCardVariant.elevated => (
        colors.surface,
        borderColor == null ? BorderSide.none : BorderSide(color: borderColor!),
      ),
      AppCardVariant.tinted => (tone.bg, BorderSide(color: borderColor ?? tone.fg.withValues(alpha: 0.18))),
    };

    Widget card = Material(
      color: fill,
      shape: RoundedRectangleBorder(borderRadius: radius, side: side),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (variant == AppCardVariant.elevated) {
      card = DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: Elevations.md(app.shadow)),
        child: card,
      );
    }
    if (onTap != null) card = PressScale(child: card);
    return semanticLabel == null
        ? card
        : Semantics(label: semanticLabel, button: onTap != null, container: true, child: card);
  }
}
