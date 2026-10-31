import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Shown while the saved session is being checked at app start. Ink like the phone's own
/// launch screen, so there is no colour jump; the mark settles in and the name follows.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppColors.of(context);
    final reduced = Motion.reduced(context);
    Widget mark = const BrandMark(size: 128, onDark: true);
    Widget title = BrandTitle(color: app.onHero);
    if (!reduced) {
      mark = mark.animate().scale(begin: const Offset(0.85, 0.85), duration: Motion.slow, curve: Curves.easeOutBack);
      title = title.animate(delay: Motion.base).fadeIn(duration: Motion.slow).slideY(begin: 0.2, end: 0);
    }
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: iconBackground),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    mark,
                    const SizedBox(height: Gaps.lg),
                    title,
                  ],
                ),
              ),
              Align(
                alignment: const Alignment(0, 0.85),
                child: SizedBox(
                  width: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: app.onHero,
                      backgroundColor: app.onHero.withValues(alpha: 0.15),
                      semanticsLabel: 'Loading',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
