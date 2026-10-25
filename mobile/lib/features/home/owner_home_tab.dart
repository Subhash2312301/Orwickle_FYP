import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/routes.dart';
import '../auth/session/session_controller.dart';
import '../listings/data/listing_api.dart';
import '../listings/data/listing_models.dart';
import '../shell/approval_banner.dart';
import '../shell/coming_soon.dart';

/// Owner's home: approval status, a summary of their listings and how listing works.
class OwnerHomeTab extends StatefulWidget {
  const OwnerHomeTab({super.key});

  @override
  State<OwnerHomeTab> createState() => _OwnerHomeTabState();
}

class _OwnerHomeTabState extends State<OwnerHomeTab> {
  List<Listing>? _listings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final listings = await context.read<ListingApi>().mine();
      if (mounted) setState(() => _listings = listings);
    } catch (_) {
      // the summary is optional; the rest of the page still works
    }
  }

  Future<void> _newListing() async {
    await context.push(Routes.newListing);
    if (mounted) _load();
  }

  int _count(bool Function(Listing) test) => _listings?.where(test).length ?? 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user!;
    final theme = Theme.of(context);
    final firstName = user.fullName.split(' ').first;

    return Scaffold(
      appBar: AppBar(title: const Text('Orwickle'), actions: const [NotificationsButton()]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const ApprovalBanner(),
            Text('Hi, $firstName', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Here is how your projects are doing.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(
                  'Live',
                  _count((l) => l.status == 'published' && l.reviewStatus == 'approved'),
                  Colors.green.shade700,
                ),
                _Stat(
                  'In review',
                  _count((l) => l.status == 'published' && l.reviewStatus == 'pending'),
                  theme.colorScheme.tertiary,
                ),
                _Stat('Drafts', _count((l) => l.status == 'draft'), Colors.orange.shade800),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _newListing, icon: const Icon(Icons.add), label: const Text('New listing')),
            const SizedBox(height: 24),
            Text('How it works', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const _Step(
              1,
              'Create a listing',
              'Public preview for everyone, confidential details only for you. Save it as a draft or publish it.',
            ),
            const _Step(2, 'Publish', 'Once your account is approved, "Save & publish" sends the listing for review.'),
            const _Step(
              3,
              'Admin review',
              'An admin checks the listing. Approved listings become visible to investors or buyers.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text('$value', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.title, this.body);

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 16, child: Text('$number')),
      title: Text(title),
      subtitle: Text(body),
    );
  }
}
