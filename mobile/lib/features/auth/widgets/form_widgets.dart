import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../session/session_controller.dart';

/// Password input with a show/hide button.
class PasswordField extends StatelessWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.errorText,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final String? errorText; // error from the server for this field
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  Widget build(BuildContext context) => AppTextField(
    controller: controller,
    label: label,
    icon: Icons.lock_outline,
    password: true,
    validator: validator,
    serverError: errorText,
    onChanged: onChanged,
    textInputAction: textInputAction,
    onSubmitted: onSubmitted,
    autofillHints: autofillHints,
  );
}

/// Live list of password rules, ticked (with a small pop) as the user types. Besides the character
/// rules it shows the two checks that otherwise only appear as an error: not the user's own [name] or
/// [email], and not a common password. So a fully ticked list always means the password is accepted.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.password, this.name, this.email});

  final String password;
  final String? name;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppColors.of(context);
    final duration = Motion.of(context, Motion.fast);
    final checks = <(String, bool)>[
      for (final rule in Validators.passwordRules.where((r) => r.label != 'At most 72 characters'))
        (rule.label, rule.isMet(password)),
      if (name != null || email != null)
        (
          'Not your name or email',
          password.isNotEmpty && !Validators.containsPersonalInfo(password, name: name, email: email),
        ),
      ('Not a common password', password.length >= 3 && !Validators.isCommonPassword(password)),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: Gaps.sm, left: Gaps.xs),
      child: Wrap(
        spacing: Gaps.md,
        runSpacing: Gaps.xs,
        children: [
          for (final (label, met) in checks)
            Semantics(
              label: '$label${met ? ', done' : ''}',
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: duration,
                    transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      met ? Icons.check_circle : Icons.radio_button_unchecked,
                      key: ValueKey(met),
                      size: IconSizes.sm,
                      color: met ? app.approved.fg : app.borderStrong,
                    ),
                  ),
                  const SizedBox(width: Gaps.xs),
                  Text(label, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Primary button that shows a spinner and ignores taps while [loading].
class LoadingButton extends StatelessWidget {
  const LoadingButton({super.key, required this.label, required this.loading, required this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AppButton(label: label, loading: loading, onPressed: onPressed);
}

/// Coloured box for a message above a form (e.g. "logged out after 15 minutes").
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message, this.icon = Icons.info_outline, this.isError = false});

  final String message;
  final IconData icon;
  final bool isError;

  @override
  Widget build(BuildContext context) =>
      AppBanner(message: message, icon: icon, role: isError ? ToneRole.rejected : ToneRole.info);
}

/// Asks "Are you sure?" before logging out, then logs out.
Future<void> confirmLogout(BuildContext context) async {
  final session = context.read<SessionController>();
  final sure = await confirmAction(
    context,
    icon: Icons.logout,
    title: 'Log out?',
    message: 'Are you sure you want to log out?',
    confirmLabel: 'Log out',
    destructive: true,
  );
  if (sure) await session.logout();
}

void showErrorSnack(BuildContext context, ApiException error) => showErrorToast(context, error);

void showInfoSnack(BuildContext context, String message) => showAppToast(context, message);
