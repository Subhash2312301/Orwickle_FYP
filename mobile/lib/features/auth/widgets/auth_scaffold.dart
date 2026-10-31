import 'package:flutter/material.dart';

import '../../../core/motion/entrance.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Common layout for the auth screens: a mark (the logo, or a tinted [icon] for a task such as
/// "verify your email"), title, subtitle and the form, centred at a readable width.
/// The heading and the form rise in one after the other.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.showBack = true,
    this.icon,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  /// Shown instead of the logo, in a cobalt tile.
  final IconData? icon;

  /// Below the form, e.g. "Already have an account? Log in".
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = ToneRole.info.resolve(context);
    final mark = icon == null
        ? const BrandLogo(size: 52)
        : Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(Radii.lg)),
            child: Icon(icon, color: tone.fg, size: IconSizes.lg + Gaps.xs),
          );

    return Scaffold(
      appBar: showBack ? const AppAppBar() : null,
      body: SafeArea(
        top: !showBack,
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.sm, Gaps.xl, Gaps.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Sizes.maxFormWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!showBack) const SizedBox(height: Gaps.xxl),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      mark,
                      const SizedBox(height: Gaps.xl),
                      Semantics(header: true, child: Text(title, style: theme.textTheme.headlineLarge)),
                      if (subtitle != null) ...[
                        const SizedBox(height: Gaps.sm),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.of(context).textMuted),
                        ),
                      ],
                    ],
                  ).entrance(context),
                  const SizedBox(height: Gaps.xl + Gaps.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ).entrance(context, index: 2),
                  if (footer != null) ...[const SizedBox(height: Gaps.lg), footer!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
