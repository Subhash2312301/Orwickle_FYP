import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../session/session_controller.dart';
import '../widgets/form_widgets.dart';

/// Logged-in password change. Other devices are logged out; this one stays logged in.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  Map<String, String> _serverErrors = const {};

  @override
  void dispose() {
    for (final c in [_current, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = const {});
    if (!_form.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await context.read<SessionController>().changePassword(
        currentPassword: _current.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      showInfoSnack(context, 'Password changed. Other devices have been logged out.');
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.fieldErrors.isNotEmpty) {
        setState(() => _serverErrors = e.fieldErrors);
      } else {
        showErrorSnack(context, e);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<SessionController>().user;
    return Scaffold(
      appBar: const AppAppBar(title: 'Change password'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Gaps.xl),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PasswordField(
                  controller: _current,
                  label: 'Current password',
                  validator: Validators.loginPassword,
                  errorText: _serverErrors['currentPassword'],
                ),
                const SizedBox(height: Gaps.lg),
                PasswordField(
                  controller: _password,
                  label: 'New password',
                  validator: (v) {
                    final error = Validators.newPassword(v, name: user?.fullName, email: user?.email);
                    if (error != null) return error;
                    return v == _current.text ? 'New password must be different from your current password' : null;
                  },
                  errorText: _serverErrors['newPassword'],
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                ),
                PasswordChecklist(password: _password.text, name: user?.fullName, email: user?.email),
                const SizedBox(height: Gaps.lg),
                PasswordField(
                  controller: _confirm,
                  label: 'Confirm new password',
                  validator: Validators.confirmPassword(() => _password.text),
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: Gaps.lg),
                const AppBanner(
                  icon: Icons.devices_other,
                  message: 'Changing your password logs you out on all other devices.',
                ),
                const SizedBox(height: Gaps.sm),
                LoadingButton(label: 'Change password', loading: _loading, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
