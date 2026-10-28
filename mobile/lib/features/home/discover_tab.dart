import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/empty_state.dart';
import '../auth/session/session_controller.dart';
import '../shell/approval_banner.dart';
import '../shell/coming_soon.dart';

/// Investors and buyers: browsing approved listings arrives in the discovery phase.
class DiscoverTab extends StatelessWidget {
  const DiscoverTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user!;
    final investor = user.role == 'investor';

    return Scaffold(
      appBar: AppBar(
        title: Text(investor ? 'Funding opportunities' : 'Projects for sale'),
        actions: const [NotificationsButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ApprovalBanner(),
          EmptyState(
            icon: Icons.travel_explore,
            badge: const ComingSoonChip(),
            title: investor ? 'Discover projects to fund' : 'Discover projects to buy',
            message: investor
                ? 'You will browse projects seeking funding here, filter by category and request access to their details.'
                : 'You will browse projects for sale here, filter by category and request access to their details.',
          ),
        ],
      ),
    );
  }
}
