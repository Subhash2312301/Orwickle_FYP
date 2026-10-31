import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Title above a group of content, with an optional subtitle, small overline and a trailing action
/// ("See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.overline,
    this.actionLabel,
    this.onAction,
    this.leading,
    this.padding = const EdgeInsets.only(top: Gaps.xl, bottom: Gaps.md),
  });

  final String title;
  final String? subtitle;
  final String? overline;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Icon before the title, e.g. a lock for the confidential section.
  final Widget? leading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppColors.of(context).textMuted;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (overline != null) ...[
                    Text(overline!.toUpperCase(), style: theme.textTheme.overline.copyWith(color: muted)),
                    const SizedBox(height: Gaps.xs),
                  ],
                  Row(
                    children: [
                      if (leading != null) ...[leading!, const SizedBox(width: Gaps.sm)],
                      Flexible(child: Text(title, style: theme.textTheme.titleLarge)),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: Gaps.xs),
                    Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                  ],
                ],
              ),
            ),
          ),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
