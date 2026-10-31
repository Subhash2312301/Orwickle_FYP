import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'chips.dart';

/// Round profile photo that fades in, or the user's initials when there is none (or it fails).
/// [verified] adds the seal at the bottom right (reserved for FYP-II verification badges).
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.initials, this.url, this.size = 48, this.verified = false, this.label});

  final String initials;
  final String? url;
  final double size;
  final bool verified;

  /// Screen reader text, e.g. "Profile photo of Sara Ahmed".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fallback = Center(
      child: Text(
        initials,
        style: theme.textTheme.titleMedium?.copyWith(
          fontFamily: theme.textTheme.headlineSmall?.fontFamily,
          fontSize: size * 0.36,
          color: colors.onPrimaryContainer,
        ),
      ),
    );

    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primaryContainer,
        border: Border.all(color: colors.surface, width: size > 64 ? 3 : 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? fallback
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
              frameBuilder: (context, child, frame, sync) => sync
                  ? child
                  : AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: Motion.of(context, Motion.base),
                      child: child,
                    ),
            ),
    );

    return Semantics(
      image: true,
      label: label,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            circle,
            if (verified)
              Positioned(
                right: -2,
                bottom: -2,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: colors.surface, shape: BoxShape.circle),
                  child: Padding(
                    padding: const EdgeInsets.all(Gaps.xxs),
                    child: VerifiedBadge(size: (size * 0.3).clamp(IconSizes.xs, IconSizes.lg)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
