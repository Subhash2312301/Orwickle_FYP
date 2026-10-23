import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/validation/validators.dart';
import '../data/auth_api.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/form_widgets.dart';
import 'auth_helpers.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final email = _email.text.trim().toLowerCase();
    setState(() => _loading = true);
    try {
      await context.read<AuthApi>().forgotPassword(email);
      if (mounted) context.pushReplacement(locationWithEmail(Routes.resetPassword, email));
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Forgot password?',
      subtitle: 'Enter your account email and we will send you a code to reset your password.',
      children: [
        Form(
          key: _form,
          child: TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            validator: Validators.email,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
          ),
        ),
        const SizedBox(height: 28),
        LoadingButton(label: 'Send code', loading: _loading, onPressed: _submit),
      ],
    );
  }
}
