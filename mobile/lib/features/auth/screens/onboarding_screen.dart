import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/storage/onboarding_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Three intro slides shown on the first start: list, discover, negotiate. Finishing or skipping
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
      'Discover',
      'Find the right match',
      'Investors browse projects seeking funding, buyers browse projects for sale, each in their own section.',
      _DiscoverArt(),
    ),
    _Slide(
      'Negotiate',
      'Negotiate with confidence',
      'Request access, make offers and counteroffers, and keep every version on record. Every account is reviewed.',
      _NegotiateArt(),
    ),
  ];

  final _pages = PageController();
  int _page = 0;

  bool get _isLast => _page == _slides.length - 1;

  void _finish() => context.read<OnboardingState>().markSeen();

  void _next() {
    if (_isLast) return _finish();
    _pages.nextPage(duration: Motion.of(context, Motion.slow), curve: Motion.emphasized);
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

class _DiscoverArt extends StatelessWidget {
  const _DiscoverArt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(bool funding, String title, String amount) => Padding(
      padding: const EdgeInsets.only(top: Gaps.md),
      child: Row(
        children: [
          ListingTypeChip(isFunding: funding, short: true),
          const SizedBox(width: Gaps.sm),
          Expanded(
            child: Text(title, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
          ),
          Text(amount, style: theme.textTheme.numeric(size: 13)),
        ],
      ),
    );
    return _MiniCard(
      width: 260,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedToggle<bool>(
            value: true,
            onChanged: null,
            segments: const [
              ToggleSegment(value: true, label: 'Funding', icon: Icons.trending_up, role: ToneRole.funding),
              ToggleSegment(value: false, label: 'Sales', icon: Icons.sell_outlined, role: ToneRole.sale),
            ],
          ),
          row(true, 'Campus delivery app', '8 lakh'),
          row(true, 'AI tutor for O-levels', '20 lakh'),
          row(false, 'Clinic booking system', '3 lakh'),
        ],
      ),
    );
  }
}

class _NegotiateArt extends StatelessWidget {
  const _NegotiateArt();

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
              const AppAvatar(initials: 'AK', size: 32),
              const SizedBox(width: Gaps.sm),
              Expanded(child: Text('Offer from Ali', style: theme.textTheme.titleSmall)),
              StatusChip.status(AppStatus.countered),
            ],
          ),
          const SizedBox(height: Gaps.md),
          Text('PKR 1,200,000', style: theme.textTheme.numeric(size: 20)),
          Text('10% equity · expires in 5 days', style: theme.textTheme.bodySmall),
          const SizedBox(height: Gaps.md),
          Row(
            children: [
              StatusChip.status(AppStatus.accepted),
              const SizedBox(width: Gaps.sm),
              const VerifiedBadge(showLabel: true),
            ],
          ),
        ],
      ),
    );
  }
}
