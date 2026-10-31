import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Six boxes for a one-time code. A single hidden text field takes the input,
/// so typing, deleting, pasting and SMS/email autofill all work normally.
/// The box waiting for the next digit glows; filled boxes pop their digit in.
class OtpInput extends StatefulWidget {
  const OtpInput({super.key, required this.controller, this.onCompleted, this.errorText});

  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final String? errorText;

  static const length = 6;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(() => setState(() {}));
  }

  void _onChanged() {
    setState(() {});
    if (widget.controller.text.length == OtpInput.length) widget.onCompleted?.call(widget.controller.text);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    final hasError = widget.errorText != null;

    return Semantics(
      label: 'Six-digit code, ${code.length} of ${OtpInput.length} entered',
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => _focus.requestFocus(),
            child: Stack(
              children: [
                // invisible field that actually receives the keyboard input
                Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: OtpInput.length,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(counterText: '', filled: false, border: InputBorder.none),
                  ),
                ),
                ExcludeSemantics(
                  child: Row(
                    children: [
                      for (var i = 0; i < OtpInput.length; i++) ...[
                        if (i > 0) SizedBox(width: i == OtpInput.length ~/ 2 ? Gaps.md : Gaps.sm),
                        Expanded(
                          child: _Box(
                            digit: i < code.length ? code[i] : '',
                            active: _focus.hasFocus && i == code.length.clamp(0, OtpInput.length - 1),
                            hasError: hasError,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          FieldError(widget.errorText),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.digit, required this.active, required this.hasError});

  final String digit;
  final bool active;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final app = AppColors.of(context);
    final border = hasError ? colors.error : (active ? colors.primary : app.border);
    final duration = Motion.of(context, Motion.fast);
    return AnimatedContainer(
      duration: duration,
      curve: Motion.standard,
      height: Sizes.inputHeight + Gaps.xs,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: border, width: active || hasError ? Sizes.focusRing : Sizes.hairline),
        boxShadow: active ? Elevations.glow(colors.primary) : null,
      ),
      child: AnimatedSwitcher(
        duration: duration,
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        child: Text(digit, key: ValueKey(digit), style: theme.textTheme.numeric(size: 24)),
      ),
    );
  }
}
