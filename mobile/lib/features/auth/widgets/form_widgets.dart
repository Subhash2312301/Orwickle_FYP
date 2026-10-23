import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/validation/validators.dart';

/// Password input with a show/hide button.
class PasswordField extends StatefulWidget {
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
  final String? errorText;   // error from the server for this field
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      validator: widget.validator,
      forceErrorText: widget.errorText,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Show password' : 'Hide password',
          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    );
  }
}

/// Live list of password rules, ticked as the user types.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final rule in Validators.passwordRules.where((r) => r.label != 'At most 72 characters'))
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  rule.isMet(password) ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: rule.isMet(password) ? Colors.green : colors.outline,
                ),
                const SizedBox(width: 4),
                Text(rule.label, style: Theme.of(context).textTheme.bodySmall),
              ],
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
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
          : Text(label),
    );
  }
}

/// Coloured box for a message above a form (e.g. "logged out after 15 minutes").
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message, this.icon = Icons.info_outline, this.isError = false});

  final String message;
  final IconData icon;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? colors.errorContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: isError ? colors.onErrorContainer : colors.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(color: isError ? colors.onErrorContainer : colors.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}

void showErrorSnack(BuildContext context, ApiException error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(error.message), behavior: SnackBarBehavior.floating));
}

void showInfoSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}
