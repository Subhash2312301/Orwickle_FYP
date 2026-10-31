import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'chips.dart';

/// Inline message box above content: info, warning, error or success, by [role].
/// Optional [title] and one text [actionLabel].
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.info_outline,
    this.role = ToneRole.info,
    this.actionLabel,
    this.onAction,
    this.margin = const EdgeInsets.only(bottom: Gaps.lg),
  });

  final String message;
  final String? title;
  final IconData icon;
  final ToneRole role;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = role.resolve(context);
    return Semantics(
      container: true,
      liveRegion: role == ToneRole.rejected,
      child: Container(
        margin: margin,
        padding: const EdgeInsets.fromLTRB(Gaps.md + Gaps.xs, Gaps.md + Gaps.xs, Gaps.lg, Gaps.md + Gaps.xs),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: tone.fg.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tone.fg, size: IconSizes.md),
            const SizedBox(width: Gaps.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(title!, style: theme.textTheme.titleSmall?.copyWith(color: tone.fg)),
                    const SizedBox(height: Gaps.xxs),
                  ],
                  Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
                  if (actionLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Gaps.xs),
                      child: TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: tone.fg),
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The platform disclaimer, in one place so the wording is always the same:
/// Orwickle never holds money or guarantees that an agreement is legally enforceable.
/// Quiet styling (neutral, small) so it is always visible without shouting.
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key, this.onLearnMore, this.margin = const EdgeInsets.symmetric(vertical: Gaps.lg)});

  static const text =
      'Orwickle does not hold funds or guarantee legal enforceability. Payments and contracts are '
      'arranged directly between you and the other party.';

  final VoidCallback? onLearnMore;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppColors.of(context);
    return Semantics(
      container: true,
      label: 'Disclaimer',
      child: Container(
        margin: margin,
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: app.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, size: IconSizes.sm, color: app.textMuted),
            const SizedBox(width: Gaps.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: theme.textTheme.bodySmall),
                  if (onLearnMore != null)
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: onLearnMore,
                      child: const Text('Terms & disclaimer'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
