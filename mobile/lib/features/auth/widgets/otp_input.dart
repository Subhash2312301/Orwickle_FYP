import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Six boxes for a one-time code. A single hidden text field takes the input,
/// so typing, deleting, pasting and SMS/email autofill all work normally.
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
    final colors = Theme.of(context).colorScheme;
    final code = widget.controller.text;
    final hasError = widget.errorText != null;

    return Column(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < OtpInput.length; i++)
                    _Box(
                      digit: i < code.length ? code[i] : '',
                      active: _focus.hasFocus && i == code.length.clamp(0, OtpInput.length - 1),
                      borderColor: hasError ? colors.error : colors.outline,
                      activeColor: colors.primary,
                    ),
                ],
              ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.errorText!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.error, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.digit, required this.active, required this.borderColor, required this.activeColor});

  final String digit;
  final bool active;
  final Color borderColor;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? activeColor : borderColor, width: active ? 2 : 1),
      ),
      child: Text(digit, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
