import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../auth/session/session_controller.dart';

/// Tells the user where their account stands in the admin review. Hidden once approved.
class ApprovalBanner extends StatelessWidget {
  const ApprovalBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    if (user == null || user.isApproved) return const SizedBox.shrink();
    final status = StatusColors.of(context);

    final (icon, title, body, onColor, canFix) = switch (user.approvalStatus) {
      'needs_evidence' => (
        Icons.help_outline,
        'More information needed',
        user.approvalNote ?? 'An admin needs more information about you.',
        status.danger,
        true,
      ),
      'rejected' => (
        Icons.cancel_outlined,
        'Account not approved',
        user.approvalNote ?? 'Please update your profile and it will be reviewed again.',
        status.danger,
        true,
      ),
      _ => (
        Icons.hourglass_top,
        'Account under review',
        'An admin is checking your profile. You will get an email once it is approved — '
            'until then you can look around${user.role == 'owner' ? ' and prepare draft listings' : ''}.',
        status.warning,
        false,
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: Gaps.lg),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: onColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: onColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: onColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: onColor, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                if (canFix)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => context.push(Routes.profileEdit),
                      child: const Text('Update profile'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
