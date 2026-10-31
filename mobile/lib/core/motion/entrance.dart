import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/tokens.dart';

/// Staggered entrance for list items and page sections: each fades in and rises slightly,
/// a little after the one before it. Skipped with reduced motion.
///
///     itemBuilder: (context, i) => ListingCard(...).entrance(context, index: i)
extension Entrance on Widget {
  /// Items past this index enter together, so long lists never wait.
  static const _maxStagger = 6;

  Widget entrance(BuildContext context, {int index = 0}) {
    if (Motion.reduced(context)) return this;
    return animate(delay: Motion.stagger * (index < _maxStagger ? index : _maxStagger))
        .fadeIn(duration: Motion.slow, curve: Motion.standard)
        .slideY(begin: 0.06, end: 0, duration: Motion.slow, curve: Motion.decelerate);
  }
}

/// Hero tag shared by a listing's card and its detail page, so the cover flies between them.
String listingHeroTag(String listingId) => 'listing-cover-$listingId';
