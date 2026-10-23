import 'package:flutter/material.dart';

/// "Already have an account? Log in" — wraps onto two lines on narrow screens.
class AuthLinkRow extends StatelessWidget {
  const AuthLinkRow({super.key, required this.text, required this.action, required this.onPressed});

  final String text;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}
