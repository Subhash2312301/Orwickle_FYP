import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/widgets.dart';
import '../auth/session/session_controller.dart';

/// The account's verification status as a chip. Approved accounts are "Profile Verified".
AppStatus accountStatus(String approvalStatus) => switch (approvalStatus) {
  'approved' => AppStatus.verified,
  'under_review' => AppStatus.underReview,
  'rejected' => AppStatus.rejected,
  'needs_evidence' => AppStatus.needsInfo,
  'expired' => AppStatus.expired,
  _ => AppStatus.inReview,
};

/// Tells the user where their account stands in the admin verification. Hidden once verified.
class ApprovalBanner extends StatelessWidget {
  const ApprovalBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    if (user == null || user.isApproved) return const SizedBox.shrink();

    final (icon, title, body, role, canFix) = switch (user.approvalStatus) {
      'needs_evidence' => (
        Icons.help_outline,
        'More evidence needed',
        '${user.approvalNote ?? 'An admin needs more evidence about you.'} '
            'Please update your profile within 30 days.',
        ToneRole.rejected,
        true,
      ),
      'expired' => (
        Icons.timer_off_outlined,
        'Verification request expired',
        'The requested evidence was not added within 30 days. Update your profile to send it for review again.',
        ToneRole.expired,
        true,
      ),
      'rejected' => (
        Icons.cancel_outlined,
        'Profile not verified',
        user.approvalNote ?? 'Please update your profile and it will be reviewed again.',
        ToneRole.rejected,
        true,
      ),
      'under_review' => (
        Icons.manage_search,
        'Profile under review',
        'An admin is checking your profile and evidence right now. You will get an email with the result.',
        ToneRole.info,
        false,
      ),
      _ => (
        Icons.hourglass_top,
        'Waiting for verification',
        'An admin will check your profile. You will get an email once it is verified — '
            'until then you can look around${user.role == 'owner' ? ' and prepare draft listings' : ''}.',
        ToneRole.pending,
        false,
      ),
    };

    return AppBanner(
      icon: icon,
      title: title,
      message: body,
      role: role,
      actionLabel: canFix ? 'Update profile' : null,
      onAction: canFix ? () => context.push(Routes.profileEdit) : null,
    );
  }
}
