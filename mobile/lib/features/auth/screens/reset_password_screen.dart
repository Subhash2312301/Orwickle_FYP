import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/validation/validators.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/form_widgets.dart';
import '../widgets/otp_input.dart';
import '../widgets/resend_code_button.dart';
import 'auth_helpers.dart';

/// Code from the email plus a new password. On success every old session ends.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  String? _codeError;
  Map<String, String> _serverErrors = const {};

  @override
  void dispose() {
    for (final c in [_code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final codeInvalid = Validators.otp(_code.text);
    setState(() {
      _codeError = codeInvalid;
      _serverErrors = const {};
    });
    final formOk = _form.currentState!.validate();
    if (codeInvalid != null || !formOk) return;

    setState(() => _loading = true);
    try {
      await context.read<AuthApi>().resetPassword(email: widget.email, otp: _code.text, newPassword: _password.text);
      if (!mounted) return;
      showInfoSnack(context, 'Password changed. Please log in with your new password.');
      context.go(Routes.login);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.fieldErrors.isNotEmpty) {
        setState(() => _serverErrors = e.fieldErrors);
      } else if (e.code.contains('OTP')) {
        _code.clear();
        setState(() => _codeError = e.message);
      } else {
        showErrorSnack(context, e);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthApi>();
    return AuthScaffold(
      title: 'Reset password',
      subtitle: 'If an account exists for ${widget.email}, we sent it a 6-digit code.',
      children: [
        OtpInput(controller: _code, errorText: _codeError ?? _serverErrors['otp']),
        ResendCodeButton(onResend: () => resendCode(context, api, widget.email, OtpPurpose.passwordReset)),
        const SizedBox(height: 8),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordField(
                controller: _password,
                label: 'New password',
                validator: (v) => Validators.newPassword(v, email: widget.email),
                errorText: _serverErrors['newPassword'],
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
              ),
              PasswordChecklist(password: _password.text),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirm,
                label: 'Confirm new password',
                validator: Validators.confirmPassword(() => _password.text),
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        LoadingButton(label: 'Change password', loading: _loading, onPressed: _submit),
      ],
    );
  }
}
