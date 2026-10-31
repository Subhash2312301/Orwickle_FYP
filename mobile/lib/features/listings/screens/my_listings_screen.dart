import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/motion/entrance.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/listing_api.dart';
import '../data/listing_models.dart';
import '../widgets/listing_widgets.dart';

/// The owner's listings with their status, filterable by status; entry point for creating new ones.
/// Two columns on tablets.
class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

/// Status filters; null = all.
const _filters = <(String, Set<AppStatus>?)>[
  ('All', null),
  ('Live', {AppStatus.live}),
  ('In review', {AppStatus.inReview}),
  ('Drafts', {AppStatus.draft, AppStatus.rejected, AppStatus.needsInfo}),
  ('Closed', {AppStatus.closed, AppStatus.suspended}),
];

class _MyListingsScreenState extends State<MyListingsScreen> {
  late Future<List<Listing>> _listings = _load();
  int _filter = 0;

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

  /// Error and empty states sit in a scrollable list, so pull-to-refresh still works.
  Widget _scrollable(Widget child) => ListView(padding: const EdgeInsets.all(Gaps.xl), children: [child]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'My listings', large: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(Routes.newListing),
        icon: const Icon(Icons.add),
        label: const Text('New listing'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: AsyncView<List<Listing>>(
          future: _listings,
          loading: const ListingSkeletonList(),
          onRetry: _reload,
          errorFallback: 'Could not load listings.',
          wrap: _scrollable,
          isEmpty: (l) => l.isEmpty,
          empty: EmptyState(
            icon: Icons.add_business_outlined,
            title: 'No listings yet',
            message:
                'List your project as "Seeking Funding" to reach investors, or "Available for Purchase" '
                'to reach buyers.',
            action: AppButton(
              label: 'Create your first listing',
              icon: Icons.add,
              expand: false,
              onPressed: () => _open(Routes.newListing),
            ),
          ),
          builder: (context, listings) {
            final statuses = _filters[_filter].$2;
            final shown = statuses == null
                ? listings
                : listings.where((l) => statuses.contains(listingStatus(l))).toList();
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _filterBar(listings)),
                if (shown.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      role: ToneRole.neutral,
                      title: 'Nothing here',
                      message: 'No listings with this status.',
                      action: AppButton.ghost(label: 'Show all', onPressed: () => setState(() => _filter = 0)),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.xxxl * 2),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        Widget card(BuildContext context, int i) => ListingCard(
                          listing: shown[i],
                          showStatus: true,
                          showOwner: false,
                          onTap: () => _open(Routes.listing(shown[i].id)),
                        ).entrance(context, index: i);
                        // phones: a list, each card as tall as it needs; tablets: two columns
                        if (constraints.crossAxisExtent < Sizes.twoColumnBreakpoint) {
                          return SliverList.separated(
                            itemCount: shown.length,
                            separatorBuilder: (_, _) => const SizedBox(height: Gaps.lg),
                            itemBuilder: card,
                          );
                        }
                        return SliverGrid.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: Gaps.lg,
                            crossAxisSpacing: Gaps.lg,
                            mainAxisExtent: _cardHeight(context),
                          ),
                          itemCount: shown.length,
                          itemBuilder: card,
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Cards in a grid need a fixed height; it grows with the text size so nothing is cut off.
  double _cardHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return ListingCard.coverHeight + 240 * scale;
  }

  Widget _filterBar(List<Listing> listings) {
    int count(Set<AppStatus>? statuses) =>
        statuses == null ? listings.length : listings.where((l) => statuses.contains(listingStatus(l))).length;
    return SizedBox(
      height: Sizes.tapTarget + Gaps.md,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gaps.page, vertical: Gaps.xs),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gaps.sm),
        itemBuilder: (context, i) => CategoryChip(
          label: '${_filters[i].$1} · ${count(_filters[i].$2)}',
          selected: _filter == i,
          onSelected: (_) => setState(() => _filter = i),
        ),
      ),
    );
  }
}
