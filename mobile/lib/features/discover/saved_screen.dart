import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/entrance.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../listings/widgets/listing_widgets.dart';
import '../shell/coming_soon.dart';
import 'mock_data.dart';

/// Projects an investor or buyer saved while browsing.
// TODO: wire in Week 9 (discovery): load and remove saved listings through the API.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  late final _saved = mockListings.take(2).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Saved', large: true, actions: [ShellActions()]),
      body: _saved.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Gaps.xl),
                child: EmptyState(
                  icon: Icons.bookmark_border,
                  title: 'Nothing saved yet',
                  message: 'Tap the bookmark on a project in Discover to keep it here.',
                  action: AppButton(
                    label: 'Discover projects',
                    icon: Icons.explore_outlined,
                    expand: false,
                    onPressed: () => context.go(Routes.discover),
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.xxl),
              itemCount: _saved.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: Gaps.lg),
              itemBuilder: (context, i) {
                if (i == _saved.length) {
                  return const AppBanner(
                    icon: Icons.science_outlined,
                    role: ToneRole.neutral,
                    message: 'Sample data: saving listings is connected in the discovery phase.',
                    margin: EdgeInsets.zero,
                  );
                }
                final l = _saved[i];
                return Dismissible(
                  key: ValueKey(l.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                    setState(() => _saved.removeAt(i));
                    showAppToast(context, 'Removed from saved');
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: Gaps.xl),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(Radii.lg),
                    ),
                    child: Icon(Icons.bookmark_remove_outlined, color: Theme.of(context).colorScheme.error),
                  ),
                  child: ListingCard(listing: l, onTap: () {}).entrance(context, index: i),
                );
              },
            ),
    );
  }
}
