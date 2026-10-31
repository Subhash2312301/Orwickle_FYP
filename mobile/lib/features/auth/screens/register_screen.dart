import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/widgets.dart';
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
      footer: AuthLinkRow(
        text: 'Already have an account?',
        action: 'Log in',
        onPressed: () => context.go(Routes.login),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: RoleBadge(role: widget.role.name, label: widget.role.label),
        ),
        const SizedBox(height: Gaps.lg),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _name,
                  label: 'Full name',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: Validators.fullName,
                  serverError: _serverErrors['fullName'],
                ),
                const SizedBox(height: Gaps.lg),
                AppTextField(
                  controller: _email,
                  label: 'Email',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  serverError: _serverErrors['email'],
                ),
                const SizedBox(height: Gaps.lg),
                PasswordField(
                  controller: _password,
                  label: 'Password',
                  validator: (v) => Validators.newPassword(v, name: _name.text, email: _email.text),
                  errorText: _serverErrors['password'],
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                ),
                PasswordChecklist(password: _password.text),
                const SizedBox(height: Gaps.lg),
                PasswordField(
                  controller: _confirm,
                  label: 'Confirm password',
                  validator: Validators.confirmPassword(() => _password.text),
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: Gaps.md),
                TermsCheckbox(
                  value: _acceptedTerms,
                  error: _termsError ? (_serverErrors['acceptTerms'] ?? 'You must accept the terms to continue') : null,
                  onChanged: (v) => setState(() {
                    _acceptedTerms = v;
                    if (v) _termsError = false;
                  }),
                ),
                const SizedBox(height: Gaps.lg),
                AppButton(label: 'Create account', loading: _loading, onPressed: _submit),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "I agree to the Terms of Use & Disclaimer": the whole row toggles the box (48 dp tall),
/// the link opens the terms.
class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({super.key, required this.value, required this.onChanged, this.error});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MergeSemantics(
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: () => onChanged(!value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Sizes.tapTarget),
              child: Row(
                children: [
                  Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), isError: error != null),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('I agree to the ', style: theme.textTheme.bodyMedium),
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => showTermsDialog(context),
                          child: const Text('Terms of Use & Disclaimer'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        FieldError(error),
      ],
    );
  }
}
