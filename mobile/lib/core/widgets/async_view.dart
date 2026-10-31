import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'error_state.dart';

/// Shows a [Future] as skeleton → content (or error), crossfading between the states.
/// Replaces hand-written FutureBuilder blocks so every screen handles loading, empty, error and
/// offline the same way.
///
///     AsyncView<List<Listing>>(
///       future: _listings,
///       loading: const ListingSkeletonList(),
///       isEmpty: (l) => l.isEmpty,
///       empty: EmptyState(...),
///       onRetry: _reload,
///       builder: (context, listings) => ...,
///     )
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.future,
    required this.builder,
    required this.loading,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.errorFallback,
    this.wrap,
  });

  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final Widget loading;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  /// Message for errors that are not API errors.
  final String? errorFallback;

  /// Wraps the error and empty states, e.g. in a scrollable ListView so pull-to-refresh still works.
  final Widget Function(Widget child)? wrap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        final Widget child;
        if (snapshot.connectionState != ConnectionState.done) {
          child = KeyedSubtree(key: const ValueKey('loading'), child: loading);
        } else if (snapshot.hasError) {
          child = KeyedSubtree(
            key: const ValueKey('error'),
            child: _wrapped(ErrorState.from(snapshot.error, onRetry: onRetry, fallback: errorFallback)),
          );
        } else if (empty != null && (isEmpty?.call(snapshot.data as T) ?? false)) {
          child = KeyedSubtree(key: const ValueKey('empty'), child: _wrapped(empty!));
        } else {
          child = KeyedSubtree(key: const ValueKey('data'), child: builder(context, snapshot.data as T));
        }
        return AnimatedSwitcher(
          duration: Motion.of(context, Motion.base),
          switchInCurve: Motion.standard,
          switchOutCurve: Motion.standard,
          layoutBuilder: (current, previous) =>
              Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
          child: child,
        );
      },
    );
  }

  Widget _wrapped(Widget child) => wrap?.call(child) ?? Center(child: SingleChildScrollView(child: child));
}
