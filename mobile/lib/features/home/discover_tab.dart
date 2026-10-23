import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/session/session_controller.dart';
import '../shell/approval_banner.dart';

/// Investors and buyers: browsing approved listings arrives in the discovery phase.
class DiscoverTab extends StatelessWidget {
  const DiscoverTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user!;
    final theme = Theme.of(context);
    final investor = user.role == 'investor';

    return Scaffold(
      appBar: AppBar(title: Text(investor ? 'Funding opportunities' : 'Projects for sale')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ApprovalBanner(),
          const SizedBox(height: 40),
          Icon(Icons.travel_explore, size: 72, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('Coming soon', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            investor
                ? 'You will browse startups seeking funding here, filter by category and request access to their details.'
                : 'You will browse software projects for sale here, filter by category and request access to their details.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
