import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Staggered entrance for list items and page sections: each fades in and rises slightly,
/// a little after the one before it. Skipped with reduced motion.
///
///     itemBuilder: (context, i) => ListingCard(...).entrance(context, index: i)
extension Entrance on Widget {
  Widget entrance(BuildContext context, {int index = 0}) =>
      Motion.reduced(context) ? this : EntranceTransition(index: index, child: this);
}

/// The animation behind [Entrance]. The stagger is part of one controller's timeline
/// (no timers), so nothing is left running if the widget goes away.
class EntranceTransition extends StatefulWidget {
  const EntranceTransition({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  /// Items past this index enter together, so long lists never wait.
  static const maxStagger = 6;

  @override
  State<EntranceTransition> createState() => _EntranceTransitionState();
}

class _EntranceTransitionState extends State<EntranceTransition> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _rise;

  /// How far (logical pixels) items rise while they fade in; fixed, so tall sections do not move far.
  static const _distance = Gaps.lg;

  @override
  void initState() {
    super.initState();
    final delay = Motion.stagger * widget.index.clamp(0, EntranceTransition.maxStagger);
    final total = delay + Motion.slow;
    final start = delay.inMicroseconds / total.inMicroseconds;
    _controller = AnimationController(vsync: this, duration: total)..forward();
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: Motion.standard),
    );
    _rise = Tween<double>(begin: _distance, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(start, 1, curve: Motion.decelerate),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: AnimatedBuilder(
      animation: _rise,
      builder: (context, child) => Transform.translate(offset: Offset(0, _rise.value), child: child),
      child: widget.child,
    ),
  );
}

/// Hero tag shared by a listing's card and its detail page, so the cover flies between them.
String listingHeroTag(String listingId) => 'listing-cover-$listingId';
