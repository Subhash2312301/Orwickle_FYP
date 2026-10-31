import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/storage/onboarding_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Three intro slides shown on the first start: list, get verified, keep details private. Finishing or skipping
/// them marks them as seen, and the router then moves on to the welcome screen.
/// Each slide's picture is built from the app's own components, so it previews the real product.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  const _Slide(this.overline, this.title, this.body, this.art);

  final String overline;
  final String title;
  final String body;
  final Widget art;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _slides = [
    _Slide(
      'List',
      'List your project',
      'Seeking funding or ready to sell? Add a public preview for everyone and keep the confidential details locked.',
      _ListArt(),
    ),
    _Slide(
      'Verify',
      'Get verified',
      'Complete your profile and upload your ID. An admin reviews every account before it goes live.',
      _VerifyArt(),
    ),
    _Slide(
      'Protect',
      'Your secrets stay yours',
      'Everyone sees the public preview. Your financials and business model stay confidential, visible only to you.',
      _PrivacyArt(),
    ),
  ];

  final _pages = PageController();
  int _page = 0;

  bool get _isLast => _page == _slides.length - 1;

  void _finish() => context.read<OnboardingState>().markSeen();

  void _next() {
    if (_isLast) return _finish();
    // with reduced motion jump straight to the next slide (a zero-length page animation is not allowed)
    if (Motion.reduced(context)) return _pages.jumpToPage(_page + 1);
    _pages.nextPage(duration: Motion.slow, curve: Motion.emphasized);
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
            constraints: const BoxConstraints(maxWidth: Sizes.maxFormWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
              child: Column(
                children: [
                  Row(
                    children: [
                      const BrandMark(size: 28),
                      const Spacer(),
                      AnimatedOpacity(
                        opacity: _isLast ? 0 : 1,
                        duration: Motion.of(context, Motion.fast),
                        child: IgnorePointer(
                          ignoring: _isLast,
                          child: TextButton(onPressed: _finish, child: const Text('Skip')),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      onPageChanged: (page) => setState(() => _page = page),
                      children: [for (final slide in _slides) _SlideView(slide)],
                    ),
                  ),
                  const SizedBox(height: Gaps.lg),
                  Semantics(
                    label: 'Slide ${_page + 1} of ${_slides.length}',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _slides.length; i++)
                          AnimatedContainer(
                            duration: Motion.of(context, Motion.base),
                            curve: Motion.emphasized,
                            margin: const EdgeInsets.symmetric(horizontal: Gaps.xs),
                            height: Gaps.sm,
                            width: i == _page ? Gaps.xl + Gaps.xs : Gaps.sm,
                            decoration: BoxDecoration(
                              color: i == _page ? colors.primary : AppColors.of(context).borderStrong,
                              borderRadius: BorderRadius.circular(Radii.pill),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Gaps.xl),
                  AppButton(
                    label: _isLast ? 'Get started' : 'Next',
                    icon: _isLast ? Icons.arrow_forward : null,
                    onPressed: _next,
                  ),
                  const SizedBox(height: Gaps.lg),
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
    // the picture shrinks first; with very large text the words scroll instead of overflowing
    return Column(
      children: [
        Expanded(
          flex: 6,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340, maxHeight: 340),
              child: AspectRatio(aspectRatio: 1, child: _ArtFrame(child: slide.art)),
            ),
          ),
        ),
        const SizedBox(height: Gaps.lg),
        Flexible(
          flex: 4,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text(
                  slide.overline.toUpperCase(),
                  style: theme.textTheme.overline.copyWith(color: theme.colorScheme.primary),
                ),
                const SizedBox(height: Gaps.sm),
                Semantics(
                  header: true,
                  child: Text(slide.title, textAlign: TextAlign.center, style: theme.textTheme.headlineLarge),
                ),
                const SizedBox(height: Gaps.md),
                Text(
                  slide.body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.of(context).textMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ink stage with a faint orbit ring, holding a slide's picture.
class _ArtFrame extends StatelessWidget {
  const _ArtFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final app = AppColors.of(context);
    return ExcludeSemantics(
      child: Container(
        decoration: BoxDecoration(
          gradient: iconBackground,
          borderRadius: BorderRadius.circular(Radii.xxl),
          boxShadow: Elevations.lg(app.shadow),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            FractionallySizedBox(
              widthFactor: 0.9,
              heightFactor: 0.9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: app.onHero.withValues(alpha: 0.08), width: Gaps.md),
                ),
              ),
            ),
            // the pictures are always light "product shots", also in dark mode
            Padding(
              padding: const EdgeInsets.all(Gaps.xl),
              // decorative and scaled to fit, so its text does not follow the system text size
              child: FittedBox(
                child: MediaQuery.withNoTextScaling(
                  child: Theme(data: AppTheme.light, child: child),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small card inside the slide pictures. Always drawn in the light theme, so it reads as a
/// bright product shot on the ink stage in both modes.
class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.child, this.width = 230});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // the light theme, set by _ArtFrame
    return Container(
      width: width,
      padding: const EdgeInsets.all(Gaps.md + Gaps.xs),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: Elevations.lg(AppColors.of(context).shadow),
      ),
      child: DefaultTextStyle(style: theme.textTheme.bodyMedium!, child: child),
    );
  }
}

class _ListArt extends StatelessWidget {
  const _ListArt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppColors.of(context);
    return _MiniCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 72,
            decoration: BoxDecoration(color: app.funding.bg, borderRadius: BorderRadius.circular(Radii.md)),
            child: Center(
              child: Icon(Icons.trending_up, color: app.funding.fg, size: IconSizes.xl),
            ),
          ),
          const SizedBox(height: Gaps.md),
          const ListingTypeChip(isFunding: true),
          const SizedBox(height: Gaps.sm),
          Text('Smart irrigation kit', style: theme.textTheme.titleMedium),
          const SizedBox(height: Gaps.xs),
          Text('PKR 1,500,000', style: theme.textTheme.numeric(size: 16)),
          const SizedBox(height: Gaps.md),
          Row(
            children: [
              Icon(Icons.lock_outline, size: IconSizes.sm, color: app.textMuted),
              const SizedBox(width: Gaps.xs),
              Text('Confidential details locked', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerifyArt extends StatelessWidget {
  const _VerifyArt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _MiniCard(
      width: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const AppAvatar(initials: 'You', size: 40, verified: true),
              const SizedBox(width: Gaps.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your profile', style: theme.textTheme.titleSmall),
                    Text('BS Computer Science', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gaps.md),
          const Wrap(
            spacing: Gaps.sm,
            runSpacing: Gaps.sm,
            children: [
              RoleBadge(role: 'owner', label: 'Project Owner'),
              StatusChip('University ID', icon: Icons.badge_outlined),
            ],
          ),
          const SizedBox(height: Gaps.md),
          StatusChip.status(AppStatus.approved, label: 'Approved by admin'),
        ],
      ),
    );
  }
}

class _PrivacyArt extends StatelessWidget {
  const _PrivacyArt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppColors.of(context);
    Widget row(IconData icon, String title, String body, Tone tone) => Padding(
      padding: const EdgeInsets.only(top: Gaps.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Gaps.sm),
            decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(Radii.md)),
            child: Icon(icon, size: IconSizes.md, color: tone.fg),
          ),
          const SizedBox(width: Gaps.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
    return _MiniCard(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Smart irrigation kit', style: theme.textTheme.titleMedium),
          row(Icons.visibility_outlined, 'Public preview', 'Title, summary, price', app.info),
          row(Icons.lock_outline, 'Confidential', 'Financials, business model', app.verified),
        ],
      ),
    );
  }
}
