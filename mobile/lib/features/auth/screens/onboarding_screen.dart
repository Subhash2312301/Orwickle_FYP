import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/storage/onboarding_state.dart';
import '../../../core/theme/app_theme.dart';

/// Three intro slides shown on the first start. Finishing or skipping them marks them as seen,
/// and the router then moves on to the welcome screen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  const _Slide(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _slides = [
    _Slide(
      Icons.rocket_launch_outlined,
      'Show your project to the right people',
      'Create a listing with photos, a public preview, and confidential details that only you control.',
    ),
    _Slide(
      Icons.handshake_outlined,
      'Find investors and buyers',
      'Investors browse projects seeking funding, buyers browse projects for sale, in two separate sections.',
    ),
    _Slide(
      Icons.verified_user_outlined,
      'Verified and safe',
      'Every account is reviewed by an admin. Your private documents are shared only with people you approve.',
    ),
  ];

  final _pages = PageController();
  int _page = 0;

  bool get _isLast => _page == _slides.length - 1;

  void _finish() => context.read<OnboardingState>().markSeen();

  void _next() {
    if (_isLast) return _finish();
    _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Visibility(
                      visible: !_isLast,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: TextButton(onPressed: _finish, child: const Text('Skip')),
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      onPageChanged: (page) => setState(() => _page = page),
                      children: [for (final slide in _slides) _SlideView(slide)],
                    ),
                  ),
                  const SizedBox(height: Gaps.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3.5),
                          height: 8,
                          width: i == _page ? 26 : 8,
                          decoration: BoxDecoration(
                            color: i == _page ? colors.primary : colors.primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(Radii.sm),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Gaps.xl),
                  FilledButton(onPressed: _next, child: Text(_isLast ? 'Get started' : 'Next')),
                  const SizedBox(height: Gaps.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView(this.slide);

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // the picture shrinks first; with very large text the words scroll instead of overflowing
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.brand.withValues(alpha: 0.12), AppTheme.brandSecondary.withValues(alpha: 0.12)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: FractionallySizedBox(
                    widthFactor: 0.4,
                    heightFactor: 0.4,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(gradient: AppTheme.gradient, shape: BoxShape.circle),
                      child: FittedBox(
                        child: Padding(
                          padding: const EdgeInsets.all(Gaps.lg),
                          child: Icon(slide.icon, size: 60, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Gaps.xl),
        Flexible(
          flex: 4,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text(slide.title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                const SizedBox(height: Gaps.sm),
                Text(
                  slide.body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
