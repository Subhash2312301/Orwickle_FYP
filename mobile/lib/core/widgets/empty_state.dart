import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'chips.dart';

/// Placeholder for an empty list or a feature that is not built yet: a small illustration,
/// a title, a short explanation and an optional call to action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.badge,
    this.action,
    this.role = ToneRole.info,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? badge; // e.g. ComingSoonChip above the title
  final Widget? action;
  final ToneRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gaps.xl, horizontal: Gaps.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyIllustration(icon: icon, role: role),
          const SizedBox(height: Gaps.xl),
          if (badge != null) ...[badge!, const SizedBox(height: Gaps.md)],
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: Gaps.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.maxFormWidth),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.of(context).textMuted),
            ),
          ),
          if (action != null) ...[const SizedBox(height: Gaps.xl), action!],
        ],
      ),
    );
  }
}

/// The empty-state picture: two tilted tinted tiles behind a raised card holding the icon.
/// Drawn from widgets, so it follows the theme and needs no image files.
class EmptyIllustration extends StatelessWidget {
  const EmptyIllustration({super.key, required this.icon, this.role = ToneRole.info, this.size = 120});

  final IconData icon;
  final ToneRole role;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = role.resolve(context);
    final app = AppColors.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    final tile = size * 0.72;

    Widget tilted(double turns, double alpha, Offset offset) => Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: turns,
        child: Container(
          width: tile,
          height: tile,
          decoration: BoxDecoration(
            color: tone.fg.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(Radii.xl),
          ),
        ),
      ),
    );

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            tilted(-0.22, 0.10, Offset(-size * 0.08, size * 0.04)),
            tilted(0.18, 0.16, Offset(size * 0.08, -size * 0.04)),
            Container(
              width: tile * 0.82,
              height: tile * 0.82,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: app.border),
                boxShadow: Elevations.md(app.shadow),
              ),
              child: Icon(icon, size: IconSizes.xl, color: tone.fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Coming soon" label for features planned for a later phase.
class ComingSoonChip extends StatelessWidget {
  const ComingSoonChip({super.key});

  @override
  Widget build(BuildContext context) => const StatusChip('Coming soon', role: ToneRole.info, icon: Icons.schedule);
}
