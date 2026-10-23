import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/image_widgets.dart';
import '../auth/session/session_controller.dart';
import '../profile/data/profile_api.dart';
import '../profile/data/profile_models.dart';

/// Home for logged-in users: profile summary, the owner's listings, account settings.
/// Discovery for investors and buyers arrives in the next phase.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MyProfile? _profile; // for photo, headline and city; the session user is enough to draw the rest

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (context.read<SessionController>().user?.role == 'admin') return;
    try {
      final profile = await context.read<ProfileApi>().getMine();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // the summary works without it
    }
  }

  Future<void> _open(String location) async {
    await context.push(location);
    if (mounted) _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    final theme = Theme.of(context);
    if (user == null) return const SizedBox.shrink();

    final subtitle = [_profile?.headline, _profile?.city].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orwickle'),
        actions: [IconButton(tooltip: 'Log out', icon: const Icon(Icons.logout), onPressed: () => session.logout())],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    UserAvatar(radius: 32, url: _profile?.avatarUrl, initials: user.initials),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.fullName, style: theme.textTheme.titleLarge),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 6),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.verified_user, size: 16),
                            label: Text(user.roleLabel),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (user.role == 'owner') ...[
              _Tile(
                icon: Icons.inventory_2_outlined,
                title: 'My listings',
                subtitle: 'Create and manage your projects',
                onTap: () => _open(Routes.myListings),
              ),
              _Tile(
                icon: Icons.add_business_outlined,
                title: 'New listing',
                subtitle: 'Seeking funding or available for purchase',
                onTap: () => _open(Routes.newListing),
              ),
            ],
            if (user.role == 'investor' || user.role == 'buyer')
              _Tile(
                icon: Icons.travel_explore,
                title: user.role == 'investor' ? 'Discover funding opportunities' : 'Discover projects for sale',
                subtitle: 'Coming in the next phase',
                enabled: false,
              ),
            const SizedBox(height: 12),
            Text('Account', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 4),
            if (user.role != 'admin')
              _Tile(
                icon: Icons.person_outline,
                title: 'Edit profile',
                subtitle: 'Photo, details, skills and interests',
                onTap: () => _open(Routes.profileEdit),
              ),
            _Tile(
              icon: Icons.password,
              title: 'Change password',
              subtitle: 'Also logs you out on other devices',
              onTap: () => _open(Routes.changePassword),
            ),
            _Tile(
              icon: Icons.timer_outlined,
              title: 'Automatic logout',
              subtitle:
                  'For your security you are logged out after ${session.idleTimeout.inMinutes} minutes without activity.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, this.onTap, this.enabled = true});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        enabled: enabled,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
