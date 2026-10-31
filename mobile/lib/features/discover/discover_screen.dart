import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/motion/entrance.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../auth/session/session_controller.dart';
import '../listings/data/listing_models.dart';
import '../listings/widgets/listing_widgets.dart';
import '../shell/approval_banner.dart';
import '../shell/coming_soon.dart';
import 'mock_data.dart';

/// Discover: Funding and Sales are separate sections (investors start on Funding, buyers on Sales).
/// Search, category chips, a filter sheet and an endless list that loads more near the end.
// TODO: wire in Week 9 (discovery): replace mockSearch with the listings search API; open the real
// listing detail (Routes.listing) instead of the preview sheet; persist the save button.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  late bool _funding = context.read<SessionController>().user?.role != 'buyer';
  Set<String> _categories = {};
  final _saved = <String>{};

  final List<Listing> _items = [];
  int _page = 0;
  bool _loading = false;
  bool _done = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _restart();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 400) _loadMore();
  }

  Future<void> _restart() async {
    setState(() {
      _items.clear();
      _page = 0;
      _done = false;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _done) return;
    setState(() => _loading = true);
    try {
      final next = await mockSearch(funding: _funding, query: _search.text, categories: _categories, page: _page);
      if (!mounted) return;
      setState(() {
        _items.addAll(next);
        _page++;
        _done = next.isEmpty;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onQuery(String _) {
    _debounce?.cancel();
    _debounce = Timer(Motion.slow, _restart);
  }

  Future<void> _openFilters() async {
    final picked = await showAppBottomSheet<Set<String>>(
      context,
      title: 'Filters',
      subtitle: _funding ? 'Projects seeking funding' : 'Projects for sale',
      builder: (context) => _FilterSheet(initial: _categories),
    );
    if (picked != null) {
      setState(() => _categories = picked);
      _restart();
    }
  }

  void _preview(Listing l) => showAppBottomSheet<void>(
    context,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IgnorePointer(
          child: ListingCard(listing: l, onTap: () {}),
        ),
        const SizedBox(height: Gaps.lg),
        const AppBanner(
          icon: Icons.schedule,
          role: ToneRole.info,
          message: 'Opening listings from Discover arrives with the discovery phase. This is sample data.',
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initialLoad = _items.isEmpty && _loading;

    return Scaffold(
      appBar: const AppAppBar(title: 'Discover', large: true, actions: [ShellActions()]),
      body: RefreshIndicator(
        onRefresh: _restart,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.sm),
              sliver: SliverList.list(
                children: [
                  const ApprovalBanner(),
                  SegmentedToggle<bool>(
                    value: _funding,
                    onChanged: (v) {
                      if (v == _funding) return;
                      setState(() => _funding = v);
                      _restart();
                    },
                    segments: const [
                      ToggleSegment(value: true, label: 'Funding', icon: Icons.trending_up, role: ToneRole.funding),
                      ToggleSegment(value: false, label: 'Sales', icon: Icons.sell_outlined, role: ToneRole.sale),
                    ],
                  ),
                  const SizedBox(height: Gaps.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: _onQuery,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Search projects',
                            prefixIcon: const Icon(Icons.search, size: IconSizes.md),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.close, size: IconSizes.md),
                                    onPressed: () {
                                      _search.clear();
                                      _restart();
                                    },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Gaps.sm),
                      Badge(
                        isLabelVisible: _categories.isNotEmpty,
                        label: Text('${_categories.length}'),
                        child: IconButton.outlined(
                          tooltip: 'Filters',
                          onPressed: _openFilters,
                          icon: const Icon(Icons.tune),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(Sizes.inputHeight, Sizes.inputHeight),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: Sizes.tapTarget + Gaps.sm,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Gaps.page),
                  itemCount: mockCategories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Gaps.sm),
                  itemBuilder: (context, i) {
                    final c = mockCategories[i];
                    return CategoryChip(
                      label: c,
                      selected: _categories.contains(c),
                      onSelected: (on) {
                        setState(() => _categories = on ? {..._categories, c} : ({..._categories}..remove(c)));
                        _restart();
                      },
                    );
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  _funding ? 'Projects seeking funding' : 'Projects available for purchase',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
            if (initialLoad)
              const SliverToBoxAdapter(child: ListingSkeletonList(count: 2))
            else if (_error != null && _items.isEmpty)
              SliverToBoxAdapter(child: ErrorState.from(_error, onRetry: _restart))
            else if (_items.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.search_off,
                  role: ToneRole.neutral,
                  title: 'No projects found',
                  message: 'Try another search or clear the filters.',
                  action: AppButton.ghost(
                    label: 'Clear filters',
                    onPressed: () {
                      _search.clear();
                      setState(() => _categories = {});
                      _restart();
                    },
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.lg, Gaps.page, Gaps.xl),
                sliver: SliverList.separated(
                  itemCount: _items.length + (_done ? 1 : 0) + (_loading ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: Gaps.lg),
                  itemBuilder: (context, i) {
                    if (i >= _items.length) {
                      return _loading
                          ? const Skeleton(child: ListingCardSkeleton())
                          : Center(child: Text("You've seen them all", style: theme.textTheme.bodySmall));
                    }
                    final l = _items[i];
                    final saved = _saved.contains(l.id);
                    return ListingCard(
                      listing: l,
                      onTap: () => _preview(l),
                      trailing: _SaveButton(
                        saved: saved,
                        onTap: () => setState(() => saved ? _saved.remove(l.id) : _saved.add(l.id)),
                      ),
                    ).entrance(context, index: i % 4);
                  },
                ),
              ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xxl),
                child: DisclaimerBanner(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bookmark on a card's cover; pops when toggled.
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: Gaps.xs),
      child: IconButton.filledTonal(
        tooltip: saved ? 'Remove from saved' : 'Save',
        isSelected: saved,
        onPressed: onTap,
        style: IconButton.styleFrom(backgroundColor: colors.surface),
        icon: AnimatedSwitcher(
          duration: Motion.of(context, Motion.fast),
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: Icon(
            saved ? Icons.bookmark : Icons.bookmark_border,
            key: ValueKey(saved),
            color: saved ? colors.primary : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Filter sheet: categories (the real one adds stage and amount range when discovery is built).
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final Set<String> initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _picked = {...widget.initial};
  String _stage = 'Any';
  String _sort = 'Newest';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget group(String title, List<String> options, String value, ValueChanged<String> onPick) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Gaps.lg),
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: Gaps.sm),
        Wrap(
          spacing: Gaps.sm,
          runSpacing: Gaps.sm,
          children: [
            for (final o in options)
              ChoiceChip(label: Text(o), selected: value == o, onSelected: (_) => setState(() => onPick(o))),
          ],
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Categories', style: theme.textTheme.titleSmall),
        const SizedBox(height: Gaps.sm),
        Wrap(
          spacing: Gaps.sm,
          runSpacing: Gaps.sm,
          children: [
            for (final c in mockCategories)
              CategoryChip(
                label: c,
                selected: _picked.contains(c),
                onSelected: (on) => setState(() => on ? _picked.add(c) : _picked.remove(c)),
              ),
          ],
        ),
        group('Stage', const ['Any', 'Idea', 'Prototype', 'MVP', 'Launched'], _stage, (v) => _stage = v),
        group('Sort by', const ['Newest', 'Amount: low to high', 'Amount: high to low'], _sort, (v) => _sort = v),
        const SizedBox(height: Gaps.xl),
        Row(
          children: [
            Expanded(
              child: AppButton.secondary(label: 'Reset', onPressed: () => setState(() => _picked = {})),
            ),
            const SizedBox(width: Gaps.md),
            Expanded(
              flex: 2,
              child: AppButton(label: 'Show results', onPressed: () => Navigator.pop(context, _picked)),
            ),
          ],
        ),
      ],
    );
  }
}
