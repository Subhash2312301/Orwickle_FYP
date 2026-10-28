import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Friendly placeholder for an empty list or a feature that is not built yet:
/// an icon in a soft brand circle, a title, a short explanation and an optional button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.badge,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? badge; // e.g. a "Coming soon" chip above the title
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gaps.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.brand.withValues(alpha: 0.16), AppTheme.brandSecondary.withValues(alpha: 0.16)],
              ),
            ),
            child: Icon(icon, size: 52, color: colors.primary),
          ),
          const SizedBox(height: Gaps.lg),
          if (badge != null) ...[badge!, const SizedBox(height: Gaps.sm)],
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: Gaps.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (action != null) ...[const SizedBox(height: Gaps.xl), action!],
        ],
      ),
    );
  }
}

/// Small "Coming soon" label for features planned for a later phase.
class ComingSoonChip extends StatelessWidget {
  const ComingSoonChip({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(Icons.schedule, size: 16, color: colors.primary),
      label: const Text('Coming soon'),
      visualDensity: VisualDensity.compact,
    );
  }
}
