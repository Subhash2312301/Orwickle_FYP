import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/motion/entrance.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../auth/session/session_controller.dart';
import '../auth/widgets/form_widgets.dart';
import '../profile/data/profile_api.dart';
import '../profile/data/profile_models.dart';
import '../shell/approval_banner.dart';

/// Profile: who you are (photo, name, role, review status) and your account actions.
/// Loading the profile also refreshes the approval status.
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
    final app = AppColors.of(context);
    final subtitle = [_profile?.headline, _profile?.city].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final status = switch (user.approvalStatus) {
      'approved' => AppStatus.approved,
      'rejected' => AppStatus.rejected,
      'needs_evidence' => AppStatus.needsInfo,
      _ => AppStatus.inReview,
    };

    final sections = <Widget>[
      const ApprovalBanner(),
      AppCard(
        variant: AppCardVariant.elevated,
        padding: const EdgeInsets.all(Gaps.xl),
        child: Column(
          children: [
            AppAvatar(
              size: 88,
              url: _profile?.avatarUrl,
              initials: user.initials,
              verified: user.isApproved,
              label: 'Profile photo of ${user.fullName}',
            ),
            const SizedBox(height: Gaps.md),
            Text(user.fullName, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: Gaps.xxs),
              Text(subtitle, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: Gaps.xxs),
            Text(user.email, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            if (user.role == 'investor' && _profile != null)
              Text(
                'CNIC ${maskCnic(_profile!.detailText('cnicNumber'))} · ${_profile!.phone ?? ''}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: Gaps.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Gaps.sm,
              runSpacing: Gaps.sm,
              children: [
                RoleBadge(role: user.role, label: user.roleLabel),
                StatusChip.status(status),
              ],
            ),
          ],
        ),
      ),
      const SectionHeader('Account'),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: Gaps.xs),
        child: Column(
          children: [
            if (user.role != 'admin')
              _ActionTile(
                icon: Icons.edit_outlined,
                title: 'Edit profile',
                subtitle: 'Photo, details and interests',
                onTap: () => _open(Routes.profileEdit),
              ),
            _ActionTile(icon: Icons.password, title: 'Change password', onTap: () => _open(Routes.changePassword)),
            _ActionTile(
              icon: Icons.tune,
              title: 'Settings',
              subtitle: 'Appearance, terms and about',
              onTap: () => context.push(Routes.settings),
            ),
          ],
        ),
      ),
      if (user.role == 'admin') ...[
        const SizedBox(height: Gaps.lg),
        const AppBanner(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Administrator',
          message: 'Reviews and moderation are done in the Orwickle admin dashboard on the web.',
        ),
      ],
      const SizedBox(height: Gaps.xl),
      AppButton.secondary(label: 'Log out', icon: Icons.logout, onPressed: () => confirmLogout(context)),
      const SizedBox(height: Gaps.md),
      Text(
        'For your security you are logged out after ${session.idleTimeout.inMinutes} minutes without activity.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(color: app.textMuted),
      ),
    ];

    return Scaffold(
      appBar: const AppAppBar(title: 'Profile', large: true),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.xxl),
          children: [
            for (final (i, section) in sections.indexed)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: Sizes.maxContentWidth),
                  child: section.entrance(context, index: i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: Sizes.tapTarget - Gaps.sm,
        height: Sizes.tapTarget - Gaps.sm,
        decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(Radii.md)),
        child: Icon(icon, size: IconSizes.md, color: colors.onPrimaryContainer),
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
