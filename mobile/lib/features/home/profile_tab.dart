import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/image_widgets.dart';
import '../auth/session/session_controller.dart';
import '../profile/data/profile_api.dart';
import '../profile/data/profile_models.dart';
import '../shell/approval_banner.dart';

/// Profile and account settings. Loading the profile also refreshes the approval status.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  MyProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<SessionController>();
    if (session.user?.role == 'admin') return;
    try {
      final profile = await context.read<ProfileApi>().getMine();
      if (!mounted) return;
      setState(() => _profile = profile);
      session.updateUser(
        session.user!.copyWith(approvalStatus: profile.reviewStatus, approvalNote: profile.reviewNote),
      );
    } catch (_) {
      // the page works from the session user alone
    }
  }

  Future<void> _open(String location) async {
    await context.push(location);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user!;
    final theme = Theme.of(context);
    final subtitle = [_profile?.headline, _profile?.city].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final (statusLabel, statusColor) = switch (user.approvalStatus) {
      'approved' => ('Approved', Colors.green.shade700),
      'rejected' => ('Not approved', theme.colorScheme.error),
      'needs_evidence' => ('More info needed', theme.colorScheme.tertiary),
      _ => ('Under review', Colors.orange.shade800),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const ApprovalBanner(),
            Center(
              child: UserAvatar(radius: 44, url: _profile?.avatarUrl, initials: user.initials),
            ),
            const SizedBox(height: 12),
            Text(user.fullName, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            if (subtitle.isNotEmpty) Text(subtitle, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            Text(user.email, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            if (user.role == 'investor' && _profile != null)
              Text(
                'CNIC ${maskCnic(_profile!.detailText('cnicNumber'))} · ${_profile!.phone ?? ''}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                Chip(avatar: const Icon(Icons.badge_outlined, size: 16), label: Text(user.roleLabel)),
                Chip(
                  avatar: Icon(user.isApproved ? Icons.verified : Icons.hourglass_top, size: 16, color: statusColor),
                  label: Text(statusLabel, style: TextStyle(color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (user.role != 'admin')
              Card(
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit profile'),
                  subtitle: const Text('Photo, details and interests'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(Routes.profileEdit),
                ),
              ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.password),
                title: const Text('Change password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(Routes.changePassword),
              ),
            ),
            if (user.role == 'admin')
              const Card(
                child: ListTile(
                  leading: Icon(Icons.admin_panel_settings_outlined),
                  title: Text('Administrator'),
                  subtitle: Text('Reviews and moderation are done in the Orwickle admin dashboard on the web.'),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => session.logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
            const SizedBox(height: 8),
            Text(
              'For your security you are logged out after ${session.idleTimeout.inMinutes} minutes without activity.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
