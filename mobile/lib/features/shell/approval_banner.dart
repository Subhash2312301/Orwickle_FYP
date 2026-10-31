import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/widgets.dart';
import '../auth/session/session_controller.dart';

/// Tells the user where their account stands in the admin review. Hidden once approved.
class ApprovalBanner extends StatelessWidget {
  const ApprovalBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    if (user == null || user.isApproved) return const SizedBox.shrink();

    final (icon, title, body, role, canFix) = switch (user.approvalStatus) {
      'needs_evidence' => (
        Icons.help_outline,
        'More information needed',
        user.approvalNote ?? 'An admin needs more information about you.',
        ToneRole.rejected,
        true,
      ),
      'rejected' => (
        Icons.cancel_outlined,
        'Account not approved',
        user.approvalNote ?? 'Please update your profile and it will be reviewed again.',
        ToneRole.rejected,
        true,
      ),
      _ => (
        Icons.hourglass_top,
        'Account under review',
        'An admin is checking your profile. You will get an email once it is approved — '
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
