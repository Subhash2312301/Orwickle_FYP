import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';

/// A feature planned for a later phase. Its tab or button is already visible so the app's
/// full scope is clear; opening it explains what is coming.
class UpcomingFeature {
  const UpcomingFeature(this.title, this.icon, this.description, this.points);

  final String title;
  final IconData icon;
  final String description;
  final List<String> points;
}

UpcomingFeature requestsFeature(String role) => UpcomingFeature(
  'Requests & offers',
  Icons.handshake_outlined,
  role == 'owner'
      ? 'Investors and buyers will ask to see your confidential details and send you offers here.'
      : 'Ask owners to see a project\'s confidential details, then make offers here.',
  role == 'owner'
      ? const [
          'Approve or reject access requests',
          'Receive offers and send counteroffers',
          'Draft agreements once an offer is accepted',
        ]
      : const [
          'Send access requests and track their status',
          'Make offers and counteroffers',
          'Draft agreements once an offer is accepted',
        ],
);

const savedFeature = UpcomingFeature(
  'Saved projects',
  Icons.bookmark_border,
  'Keep the projects you are interested in one tap away.',
  ['Save listings while you browse', 'Get notified when a saved listing changes'],
);

const messagesFeature = UpcomingFeature(
  'Messages',
  Icons.chat_bubble_outline,
  'Chat one-to-one once an owner approves your access request.',
  ['Real-time chat with approved connections', 'Share private documents through expiring links'],
);

const notificationsFeature = UpcomingFeature(
  'Notifications',
  Icons.notifications_outlined,
  'In-app alerts for everything that needs your attention.',
  ['New access requests and offers', 'Approvals, messages and agreement updates'],
);

/// Full page for a tab whose feature is not built yet.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage(this.feature, {super.key});

  final UpcomingFeature feature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(title: feature.title, large: true, actions: const [ShellActions()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.xxl),
        children: [_ComingSoonBody(feature)],
      ),
    );
  }
}

/// The same message as a bottom sheet, for buttons (e.g. the notifications bell).
Future<void> showComingSoon(BuildContext context, UpcomingFeature feature) =>
    showAppBottomSheet<void>(context, builder: (context) => _ComingSoonBody(feature));

class _ComingSoonBody extends StatelessWidget {
  const _ComingSoonBody(this.feature);

  final UpcomingFeature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final approved = AppColors.of(context).approved.fg;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EmptyState(
          icon: feature.icon,
          badge: const ComingSoonChip(),
          title: feature.title,
          message: feature.description,
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: Gaps.sm),
          child: Column(
            children: [
              for (final point in feature.points)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.check_circle_outline, color: approved, size: IconSizes.md),
                  title: Text(point, style: theme.textTheme.bodyMedium),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chat and notifications entry points for the top bar of every tab. Both open a "Coming soon"
/// sheet for now; when they are built they become routes, without touching the tabs.
class ShellActions extends StatelessWidget {
  const ShellActions({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Messages',
        onPressed: () => showComingSoon(context, messagesFeature),
        icon: const Icon(Icons.chat_bubble_outline),
      ),
      IconButton(
        tooltip: 'Notifications',
        onPressed: () => showComingSoon(context, notificationsFeature),
        icon: const Icon(Icons.notifications_outlined),
      ),
    ],
  );
}
