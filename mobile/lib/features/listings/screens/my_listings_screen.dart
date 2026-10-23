import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../data/listing_api.dart';
import '../data/listing_models.dart';
import '../widgets/listing_widgets.dart';

/// The owner's listings with their status; entry point for creating new ones.
class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  late Future<List<Listing>> _listings = _load();

  Future<List<Listing>> _load() => context.read<ListingApi>().mine();

  Future<void> _reload() async {
    final next = _load();
    setState(() => _listings = next);
    await next;
  }

  Future<void> _open(String location) async {
    await context.push(location);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My listings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(Routes.newListing),
        icon: const Icon(Icons.add),
        label: const Text('New listing'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Listing>>(
          future: _listings,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final message = snapshot.error is ApiException
                  ? (snapshot.error! as ApiException).message
                  : 'Could not load listings.';
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(message)),
                  Center(
                    child: TextButton(onPressed: _reload, child: const Text('Try again')),
                  ),
                ],
              );
            }
            final listings = snapshot.data!;
            if (listings.isEmpty) return const _EmptyState();
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: listings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  _ListingCard(listings[i], onTap: () => _open(Routes.listing(listings[i].id))),
            );
          },
        ),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard(this.listing, {required this.onTap});

  final Listing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListingCover(url: listing.coverUrl, isFunding: listing.isFunding, height: 120),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListingChips(listing),
                  const SizedBox(height: 8),
                  Text(listing.title, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    listing.shortDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${listing.categoryName} · ${formatAmount(listing.askingAmount, listing.currency)}',
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ListView so pull-to-refresh still works
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.inventory_2_outlined, size: 72, color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Text('No listings yet', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'List your project as "Seeking Funding" to reach investors, or "Available for Purchase" to reach buyers.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
