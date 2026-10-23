import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/validation/validators.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import '../session/session_controller.dart';
import '../widgets/auth_link_row.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/form_widgets.dart';
import 'auth_helpers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  String? _error;
  Map<String, String> _serverErrors = const {};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _serverErrors = const {};
    });
    if (!_form.currentState!.validate()) return;

    final email = _email.text.trim().toLowerCase();
    setState(() => _loading = true);
    try {
      await context.read<SessionController>().login(email: email, password: _password.text);
      // the router sends the user on once the session is active
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'EMAIL_NOT_VERIFIED') {
        await resendCode(context, context.read<AuthApi>(), email, OtpPurpose.emailVerify);
        if (mounted) context.push(locationWithEmail(Routes.verifyEmail, email));
      } else if (e.fieldErrors.isNotEmpty) {
        setState(() => _serverErrors = e.fieldErrors);
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = context.watch<SessionController>().lastLogoutReason;
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Log in to your Orwickle account',
      children: [
        if (reason == LogoutReason.inactivity)
          const InfoBanner(
            icon: Icons.timer_outlined,
            message: 'You were logged out after 15 minutes of inactivity to keep your account safe.',
          )
        else if (reason == LogoutReason.expired)
          const InfoBanner(icon: Icons.lock_clock, message: 'Your session has expired. Please log in again.'),
        if (_error != null) InfoBanner(message: _error!, icon: Icons.error_outline, isError: true),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  forceErrorText: _serverErrors['email'],
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _password,
                  label: 'Password',
                  validator: Validators.loginPassword,
                  errorText: _serverErrors['password'],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(Routes.forgotPassword),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),
                LoadingButton(label: 'Log in', loading: _loading, onPressed: _submit),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AuthLinkRow(text: "Don't have an account?", action: 'Sign up', onPressed: () => context.go(Routes.welcome)),
      ],
    );
  }
}
