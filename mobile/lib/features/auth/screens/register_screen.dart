import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/validation/validators.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import '../widgets/auth_link_row.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/form_widgets.dart';
import '../widgets/terms_dialog.dart';
import 'auth_helpers.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  bool _acceptedTerms = false;
  bool _termsError = false;
  Map<String, String> _serverErrors = const {};

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _serverErrors = const {};
      _termsError = !_acceptedTerms;
    });
    final formOk = _form.currentState!.validate();
    if (!formOk || !_acceptedTerms) return;

    final api = context.read<AuthApi>();
    final email = _email.text.trim().toLowerCase();
    setState(() => _loading = true);
    try {
      await api.register(
        fullName: _name.text.trim(),
        email: email,
        password: _password.text,
        role: widget.role,
        acceptTerms: _acceptedTerms,
      );
      if (mounted) context.go(locationWithEmail(Routes.verifyEmail, email));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'EMAIL_NOT_VERIFIED') {
        // account exists but was never verified: send a fresh code and continue there
        await resendCode(context, api, email, OtpPurpose.emailVerify);
        if (mounted) context.go(locationWithEmail(Routes.verifyEmail, email));
      } else if (e.code == 'EMAIL_TAKEN') {
        setState(() => _serverErrors = {'email': e.message});
      } else if (e.fieldErrors.isNotEmpty) {
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
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Signing up as ${widget.role.label}',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: Validators.fullName,
                  forceErrorText: _serverErrors['fullName'],
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 16),
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
                  validator: (v) => Validators.newPassword(v, name: _name.text, email: _email.text),
                  errorText: _serverErrors['password'],
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                ),
                PasswordChecklist(password: _password.text),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _confirm,
                  label: 'Confirm password',
                  validator: Validators.confirmPassword(() => _password.text),
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                _TermsCheckbox(
                  value: _acceptedTerms,
                  error: _termsError ? (_serverErrors['acceptTerms'] ?? 'You must accept the terms to continue') : null,
                  onChanged: (v) => setState(() {
                    _acceptedTerms = v;
                    if (v) _termsError = false;
                  }),
                ),
                const SizedBox(height: 16),
                LoadingButton(label: 'Create account', loading: _loading, onPressed: _submit),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AuthLinkRow(text: 'Already have an account?', action: 'Log in', onPressed: () => context.go(Routes.login)),
      ],
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.value, required this.onChanged, this.error});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), isError: error != null),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('I agree to the '),
                  GestureDetector(
                    onTap: () => showTermsDialog(context),
                    child: Text(
                      'Terms of Use & Disclaimer',
                      style: TextStyle(color: colors.primary, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(error!, style: TextStyle(color: colors.error, fontSize: 12)),
          ),
      ],
    );
  }
}
