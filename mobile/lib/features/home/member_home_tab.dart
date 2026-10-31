import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/motion/entrance.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../auth/session/session_controller.dart';
import '../shell/approval_banner.dart';

/// Home for investors and buyers: a greeting, where their account review stands and a shortcut to
/// their profile. (Browsing listings belongs to the discovery phase.)
class MemberHomeTab extends StatelessWidget {
  const MemberHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppColors.of(context);
    final user = context.watch<SessionController>().user!;
    final firstName = user.fullName.split(' ').first;
    final status = switch (user.approvalStatus) {
      'approved' => AppStatus.approved,
      'rejected' => AppStatus.rejected,
      'needs_evidence' => AppStatus.needsInfo,
      _ => AppStatus.inReview,
    };

    final sections = <Widget>[
      const ApprovalBanner(),
      Container(
        padding: const EdgeInsets.all(Gaps.xl),
        decoration: BoxDecoration(
          gradient: iconBackground,
          borderRadius: BorderRadius.circular(Radii.xl),
          boxShadow: Elevations.md(app.shadow),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi, $firstName', style: theme.textTheme.headlineMedium?.copyWith(color: app.onHero)),
            const SizedBox(height: Gaps.xs),
            Text(
              'Welcome to Orwickle. Your ${user.roleLabel.toLowerCase()} account is set up.',
              style: theme.textTheme.bodyMedium?.copyWith(color: app.onHero.withValues(alpha: 0.72)),
            ),
            const SizedBox(height: Gaps.lg),
            Wrap(
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
      const SectionHeader('Your account'),
      AppCard(
        onTap: () => context.go(Routes.profile),
        child: Row(
          children: [
            AppAvatar(initials: user.initials, size: 48, verified: user.isApproved),
            const SizedBox(width: Gaps.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: theme.textTheme.titleMedium),
                  Text(user.email, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
      const SizedBox(height: Gaps.md),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: Gaps.sm),
        child: Column(
          children: [
            for (final (i, (icon, title, body)) in const [
              (Icons.person_outline, 'Profile completed', 'Your details and verification documents are saved.'),
              (Icons.verified_outlined, 'Admin review', 'An admin checks your profile and documents.'),
              (Icons.mark_email_read_outlined, 'Approval email', 'You get an email once your account is approved.'),
            ].indexed)
              ListTile(
                leading: Container(
                  width: Sizes.tapTarget - Gaps.sm,
                  height: Sizes.tapTarget - Gaps.sm,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Icon(icon, size: IconSizes.md, color: theme.colorScheme.onPrimaryContainer),
                ),
                title: Text('${i + 1}. $title'),
                subtitle: Text(body),
              ),
          ],
        ),
      ),
      const DisclaimerBanner(),
    ];

    return Scaffold(
      appBar: const AppAppBar(
        leading: Padding(padding: EdgeInsets.all(Gaps.md), child: BrandMark(size: 28)),
        title: 'Orwickle',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.xxl),
        children: [
          for (final (i, s) in sections.indexed)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Sizes.maxContentWidth),
                child: s.entrance(context, index: i),
              ),
            ),
        ],
      ),
    );
  }
}
