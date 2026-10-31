import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A number that counts up to [value] (and animates between later values).
/// Uses tabular figures so the width does not jitter; shows the final value at once with
/// reduced motion.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({super.key, required this.value, this.style, this.format, this.semanticsLabel});

  final num value;
  final TextStyle? style;

  /// e.g. (n) => formatAmount(n, 'PKR'); defaults to a whole number.
  final String Function(num value)? format;
  final String? semanticsLabel;

  static const _duration = Duration(milliseconds: 900);

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? Theme.of(context).textTheme.numeric(size: 28);
    String show(num n) => format?.call(n) ?? n.round().toString();
    return Semantics(
      label: semanticsLabel ?? show(value),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: Motion.of(context, _duration),
        curve: Motion.decelerate,
        builder: (context, current, _) => Text(show(current), style: textStyle),
      ),
    );
  }
}
