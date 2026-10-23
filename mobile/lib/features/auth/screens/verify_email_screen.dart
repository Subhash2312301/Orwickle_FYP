import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/validation/validators.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import '../session/session_controller.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/form_widgets.dart';
import '../widgets/otp_input.dart';
import '../widgets/resend_code_button.dart';
import 'auth_helpers.dart';

/// Enter the 6-digit code from the email. Success logs the user in;
/// the router then moves on automatically.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final invalid = Validators.otp(_code.text);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<SessionController>().verifyEmail(email: widget.email, otp: _code.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'EMAIL_ALREADY_VERIFIED') {
        showInfoSnack(context, e.message);
        context.go(Routes.login);
        return;
      }
      _code.clear();
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthApi>();
    return AuthScaffold(
      title: 'Verify your email',
      subtitle: 'Enter the 6-digit code we sent to\n${widget.email}',
      children: [
        OtpInput(controller: _code, errorText: _error, onCompleted: (_) => _verify()),
        const SizedBox(height: 28),
        LoadingButton(label: 'Verify', loading: _loading, onPressed: _verify),
        const SizedBox(height: 8),
        ResendCodeButton(onResend: () => resendCode(context, api, widget.email, OtpPurpose.emailVerify)),
        Text('The code is valid for 10 minutes. Check your spam folder if you cannot find it.',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
