import 'package:flutter/material.dart';

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
      appBar: AppBar(title: Text(feature.title)),
      body: ListView(padding: const EdgeInsets.all(24), children: [_ComingSoonBody(feature)]),
    );
  }
}

/// The same message as a bottom sheet, for buttons (e.g. the notifications bell).
Future<void> showComingSoon(BuildContext context, UpcomingFeature feature) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true, // sized to its content, scrolls on short screens
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: _ComingSoonBody(feature),
    ),
  ),
);

class _ComingSoonBody extends StatelessWidget {
  const _ComingSoonBody(this.feature);

  final UpcomingFeature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Icon(feature.icon, size: 64, color: theme.colorScheme.outline),
        const SizedBox(height: 12),
        Chip(
          avatar: Icon(Icons.schedule, size: 16, color: theme.colorScheme.primary),
          label: const Text('Coming soon'),
        ),
        const SizedBox(height: 8),
        Text(feature.title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(feature.description, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        for (final point in feature.points)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
            title: Text(point),
          ),
      ],
    );
  }
}

/// Bell in the app bar; notifications arrive in a later phase.
class NotificationsButton extends StatelessWidget {
  const NotificationsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Notifications',
    onPressed: () => showComingSoon(context, notificationsFeature),
    icon: const Icon(Icons.notifications_outlined),
  );
}
