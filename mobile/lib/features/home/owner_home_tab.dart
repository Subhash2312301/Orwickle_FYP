import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/motion/entrance.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../auth/session/session_controller.dart';
import '../listings/data/listing_api.dart';
import '../listings/data/listing_models.dart';
import '../listings/widgets/listing_widgets.dart';
import '../shell/approval_banner.dart';
import '../shell/coming_soon.dart';

/// Owner's home: a greeting with live / in review / draft counts, the latest listings and how
/// listing works. "Create listing" is always one tap away.
class OwnerHomeTab extends StatefulWidget {
  const OwnerHomeTab({super.key});

  @override
  State<OwnerHomeTab> createState() => _OwnerHomeTabState();
}

class _OwnerHomeTabState extends State<OwnerHomeTab> {
  late Future<List<Listing>> _listings = _load();

  Future<List<Listing>> _load() => context.read<ListingApi>().mine();

  Future<void> _reload() async {
    final next = _load();
    setState(() => _listings = next);
    await next.catchError((_) => <Listing>[]);
  }

  Future<void> _open(String location) async {
    await context.push(location);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user!;
    final firstName = user.fullName.split(' ').first;

    return Scaffold(
      appBar: const AppAppBar(
        leading: Padding(padding: EdgeInsets.all(Gaps.md), child: BrandMark(size: 28)),
        title: 'Orwickle',
        actions: [ShellActions()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(Routes.newListing),
        icon: const Icon(Icons.add),
        label: const Text('Create listing'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Listing>>(
          future: _listings,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            final listings = snapshot.data ?? const <Listing>[];
            final sections = <Widget>[
              const ApprovalBanner(),
              _StatsHeader(name: firstName, listings: listings, loading: loading),
              SectionHeader(
                'Your latest listings',
                actionLabel: listings.isEmpty ? null : 'See all',
                onAction: () => context.go(Routes.myListings),
              ),
              if (loading)
                const Skeleton(child: ListingCardSkeleton())
              else if (snapshot.hasError)
                ErrorState.from(snapshot.error, fallback: 'Could not load your listings.', onRetry: _reload)
              else if (listings.isEmpty)
                AppCard(
                  child: EmptyState(
                    icon: Icons.add_business_outlined,
                    title: 'List your first project',
                    message: 'Choose "Seeking Funding" to reach investors or "Available for Purchase" to reach buyers.',
                    action: AppButton(
                      label: 'Create listing',
                      icon: Icons.add,
                      expand: false,
                      onPressed: () => _open(Routes.newListing),
                    ),
                  ),
                )
              else
                for (final l in listings.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gaps.lg),
                    child: ListingCard(
                      listing: l,
                      showStatus: true,
                      showOwner: false,
                      onTap: () => _open(Routes.listing(l.id)),
                    ),
                  ),
              const SectionHeader('How it works'),
              const _HowItWorks(),
              const DisclaimerBanner(),
            ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.xxxl * 2),
              children: [
                for (final (i, s) in sections.indexed)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: Sizes.maxContentWidth),
                      child: s.entrance(context, index: i),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Ink header: greeting and three counters that count up when the listings arrive.
class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.name, required this.listings, required this.loading});

  final String name;
  final List<Listing> listings;
  final bool loading;

  int _count(AppStatus status) => listings.where((l) => listingStatus(l) == status).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppColors.of(context);
    // the header is always ink, so its dots use the dark theme's tones in both modes
    const onInk = AppColors.dark;
    final stats = [
      ('Live', _count(AppStatus.live), onInk.approved),
      ('In review', _count(AppStatus.inReview), onInk.pending),
      ('Drafts', _count(AppStatus.draft) + _count(AppStatus.rejected) + _count(AppStatus.needsInfo), onInk.info),
    ];
    return Container(
      padding: const EdgeInsets.all(Gaps.xl),
      decoration: BoxDecoration(
        gradient: iconBackground,
        borderRadius: BorderRadius.circular(Radii.xl),
        boxShadow: Elevations.md(app.shadow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hi, $name', style: theme.textTheme.headlineMedium?.copyWith(color: app.onHero)),
          const SizedBox(height: Gaps.xs),
          Text(
            'Turn your ideas into real projects. Here is how they are doing.',
            style: theme.textTheme.bodyMedium?.copyWith(color: app.onHero.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: Gaps.xl),
          Row(
            children: [
              for (final (i, (label, value, tone)) in stats.indexed) ...[
                if (i > 0)
                  Container(
                    width: Sizes.hairline,
                    height: Gaps.xxxl,
                    color: app.onHero.withValues(alpha: 0.12),
                    margin: const EdgeInsets.symmetric(horizontal: Gaps.md),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      loading
                          ? Text('–', style: theme.textTheme.numeric(size: 28).copyWith(color: app.onHero))
                          : AnimatedCounter(
                              value: value,
                              semanticsLabel: '$value $label',
                              style: theme.textTheme
                                  .numeric(size: 28, weight: FontWeight.w800)
                                  .copyWith(color: app.onHero),
                            ),
                      const SizedBox(height: Gaps.xs),
                      Row(
                        children: [
                          Container(
                            width: Gaps.sm,
                            height: Gaps.sm,
                            decoration: BoxDecoration(color: tone.fg, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: Gaps.xs + Gaps.xxs),
                          Flexible(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(color: app.onHero.withValues(alpha: 0.8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The three steps from draft to live, as a small numbered list.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (
      Icons.edit_note,
      'Create a listing',
      'Public preview for everyone, confidential details only for you. Save it as a draft or publish it.',
    ),
    (Icons.publish, 'Publish', 'Once your account is approved, "Save & publish" sends the listing for review.'),
    (
      Icons.verified_outlined,
      'Admin review',
      'An admin checks the listing. Approved listings become visible to investors or buyers.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: Gaps.sm),
      child: Column(
        children: [
          for (final (i, (icon, title, body)) in _steps.indexed)
            ListTile(
              leading: Container(
                width: Sizes.tapTarget - Gaps.sm,
                height: Sizes.tapTarget - Gaps.sm,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Icon(icon, size: IconSizes.md, color: colors.onPrimaryContainer),
              ),
              title: Text('${i + 1}. $title'),
              subtitle: Text(body),
            ),
        ],
      ),
    );
  }
}
