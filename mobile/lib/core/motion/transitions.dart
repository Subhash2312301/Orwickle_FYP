import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';

/// Page transitions, all skipped when the system asks for reduced motion:
///
/// * pushing a screen (default, via the theme): shared axis, horizontal — the new page slides in
///   a little while the old one fades, which reads as "going deeper";
/// * switching between unrelated places (splash → onboarding → welcome → home): fade through;
/// * creating something (new listing): slides up from the bottom, like a modal.

/// Theme-wide builder for pushed pages.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static const _sharedAxis = SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.horizontal);

  @override
  Duration get transitionDuration => Motion.slow;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Motion.reduced(context)) return child;
    return _sharedAxis.buildTransitions(route, context, animation, secondaryAnimation, child);
  }
}

/// The same builder for every platform, so Android, iOS and web feel alike.
const appPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: AppPageTransitionsBuilder(),
    TargetPlatform.iOS: AppPageTransitionsBuilder(),
    TargetPlatform.macOS: AppPageTransitionsBuilder(),
    TargetPlatform.windows: AppPageTransitionsBuilder(),
    TargetPlatform.linux: AppPageTransitionsBuilder(),
    TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
  },
);

/// go_router page that fades through (old page fades out, new one fades and scales in).
Page<void> fadeThroughPage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: Motion.slow,
  reverseTransitionDuration: Motion.base,
  transitionsBuilder: (context, animation, secondary, child) => Motion.reduced(context)
      ? child
      : FadeThroughTransition(animation: animation, secondaryAnimation: secondary, child: child),
);

/// go_router page that slides up from the bottom and down again when closed.
Page<T> slideUpPage<T>(GoRouterState state, Widget child) => CustomTransitionPage<T>(
  key: state.pageKey,
  child: child,
  fullscreenDialog: true,
  transitionDuration: Motion.slow,
  reverseTransitionDuration: Motion.base,
  transitionsBuilder: (context, animation, secondary, child) {
    if (Motion.reduced(context)) return child;
    final curved = CurvedAnimation(parent: animation, curve: Motion.emphasized, reverseCurve: Motion.standard);
    return SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
      child: child,
    );
  },
);

/// Holds the tab branches like an IndexedStack (each keeps its scroll position and loaded data),
/// and fades through to the newly selected tab. Inactive tabs stop their animations.
class FadeThroughBranches extends StatefulWidget {
  const FadeThroughBranches({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<FadeThroughBranches> createState() => _FadeThroughBranchesState();
}

class _FadeThroughBranchesState extends State<FadeThroughBranches> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.base, value: 1);
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.2, 1, curve: Motion.standard),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.97,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Motion.standard));

  static const Animation<double> _still = AlwaysStoppedAnimation(1);

  @override
  void didUpdateWidget(FadeThroughBranches old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      Motion.reduced(context) ? _controller.value = 1 : _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      sizing: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          // the same widget types for every branch, active or not, so no branch loses its state
          TickerMode(
            enabled: i == widget.index,
            child: FadeTransition(
              opacity: i == widget.index ? _fade : _still,
              child: ScaleTransition(scale: i == widget.index ? _scale : _still, child: widget.children[i]),
            ),
          ),
      ],
    );
  }
}
