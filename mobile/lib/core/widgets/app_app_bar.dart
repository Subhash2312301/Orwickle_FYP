import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Top bar for every screen: title (and optional subtitle) on the page background, no tint on scroll.
/// [large] uses the bigger headline for the root page of a tab.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.large = false,
    this.bottom,
  });

  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool large;
  final PreferredSizeWidget? bottom;

  static const double _largeHeight = 72;

  @override
  Size get preferredSize =>
      Size.fromHeight((large ? _largeHeight : kToolbarHeight) + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      toolbarHeight: large ? _largeHeight : kToolbarHeight,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: [
        ...?actions,
        const SizedBox(width: Gaps.xs),
      ],
      bottom: bottom,
      title: title == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title!, style: large ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge),
                if (subtitle != null)
                  Text(subtitle!, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
    );
  }
}
