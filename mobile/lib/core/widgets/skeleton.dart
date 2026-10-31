import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

/// Shimmering placeholder shown while content loads. Wrap a layout of [SkeletonBox]es in it;
/// the shimmer pauses when the system asks for reduced motion. Announced as "Loading".
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  static const _sweep = Duration(milliseconds: 1300);

  @override
  Widget build(BuildContext context) {
    final highlight = Theme.of(context).colorScheme.surface.withValues(alpha: 0.6);
    final body = Motion.reduced(context)
        ? child
        : child
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: _sweep, color: highlight, curve: Curves.easeInOut);
    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: ExcludeSemantics(child: body),
    );
  }
}

/// One grey block of a skeleton. [width] null = fill the row.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = Radii.sm});

  /// A circle, e.g. an avatar.
  const SkeletonBox.circle({super.key, required double size}) : width = size, height = size, radius = Radii.pill;

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: AppColors.of(context).skeleton, borderRadius: BorderRadius.circular(radius)),
  );
}

/// A few text-like lines, the last one shorter.
class SkeletonLines extends StatelessWidget {
  const SkeletonLines({super.key, this.lines = 3, this.lineHeight = 12});

  final int lines;
  final double lineHeight;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < lines; i++) ...[
        if (i > 0) const SizedBox(height: Gaps.sm),
        FractionallySizedBox(
          widthFactor: i == lines - 1 ? 0.6 : 1,
          child: SkeletonBox(height: lineHeight),
        ),
      ],
    ],
  );
}
