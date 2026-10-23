import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/routes.dart';
import '../auth/session/session_controller.dart';

/// Placeholder home for logged-in users. Profile setup (Step 3) and listings (Phase 3) come next.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    final theme = Theme.of(context);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orwickle'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => session.logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(user.initials,
                  style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
            ),
          ),
          const SizedBox(height: 16),
          Text(user.fullName, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(user.email, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Center(child: Chip(avatar: const Icon(Icons.verified_user, size: 18), label: Text(user.roleLabel))),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Complete your profile'),
              subtitle: const Text('Coming in the next step'),
              trailing: const Icon(Icons.chevron_right),
              enabled: false,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.password),
              title: const Text('Change password'),
              subtitle: const Text('Also logs you out on other devices'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.changePassword),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Automatic logout'),
              subtitle: Text('For your security you are logged out after '
                  '${session.idleTimeout.inMinutes} minutes without activity.'),
            ),
          ),
        ],
      ),
    );
  }
}
