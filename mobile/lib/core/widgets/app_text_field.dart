import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// The app's text input, as a form field.
///
/// * [validator] runs on submit; [serverError] shows a message from the API under the field.
/// * [password] adds a show / hide button and turns off suggestions.
/// * Focus moves the label up, thickens the cobalt border and tints the icon (all animated by
///   the theme); errors slide in under the field.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.icon,
    this.validator,
    this.serverError,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.showCounter = false,
    this.textCapitalization = TextCapitalization.none,
    this.password = false,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final IconData? icon;
  final FormFieldValidator<String>? validator;
  final String? serverError;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final bool showCounter;
  final TextCapitalization textCapitalization;
  final bool password;
  final bool enabled;
  final bool autofocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final multiline = widget.maxLines > 1;
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      obscureText: widget.password && _hidden,
      enableSuggestions: !widget.password,
      autocorrect: !widget.password,
      keyboardType: widget.keyboardType ?? (multiline ? TextInputType.multiline : null),
      textInputAction: widget.textInputAction ?? (multiline ? TextInputAction.newline : TextInputAction.next),
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      maxLines: widget.password ? 1 : widget.maxLines,
      minLines: widget.minLines ?? (multiline ? 2 : null),
      maxLength: widget.maxLength,
      textCapitalization: widget.textCapitalization,
      validator: widget.validator,
      forceErrorText: widget.serverError,
      autovalidateMode: AutovalidateMode.onUnfocus,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
        helperMaxLines: 2,
        errorMaxLines: 3,
        alignLabelWithHint: multiline,
        counterText: widget.showCounter ? null : '',
        prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: IconSizes.md),
        suffixIcon: widget.password
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: IconSizes.md),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}

/// A choice from a short list, styled like [AppTextField].
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.requiredError,
    this.serverError,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final Map<T, String> options;
  final ValueChanged<T?> onChanged;

  /// Message when nothing is chosen; null = optional.
  final String? requiredError;
  final String? serverError;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: options.containsKey(value) ? value : null,
      isExpanded: true,
      borderRadius: BorderRadius.circular(Radii.md),
      items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
      onChanged: enabled ? onChanged : null,
      validator: (v) => v == null ? requiredError : null,
      forceErrorText: serverError,
      decoration: InputDecoration(
        labelText: label,
        errorMaxLines: 3,
        prefixIcon: icon == null ? null : Icon(icon, size: IconSizes.md),
      ),
    );
  }
}

/// Error line under a custom form field (chips, documents, choices), matching the text fields'.
/// Appears and disappears with a short fade and size animation.
class FieldError extends StatelessWidget {
  const FieldError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSize(
      duration: Motion.of(context, Motion.fast),
      curve: Motion.standard,
      alignment: Alignment.topLeft,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: Gaps.sm, left: Gaps.md),
              child: Semantics(liveRegion: true, child: Text(message!, style: theme.inputDecorationTheme.errorStyle)),
            ),
    );
  }
}
