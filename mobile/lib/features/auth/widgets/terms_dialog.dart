import 'package:flutter/material.dart';

/// Terms of use and disclaimer, shown from the register screen.
/// Wording follows the scope and disclaimers in the project proposal.
Future<void> showTermsDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Terms of Use & Disclaimer'),
    content: const SingleChildScrollView(
      child: Text(
        '1. Orwickle is a platform for discovering projects, requesting access and recording '
        'offers and draft agreements between project owners, investors and buyers.\n\n'
        '2. Orwickle does not approve investments, hold or transfer money, process payments '
        'or guarantee any payment. Payment and legal execution are handled by the parties themselves.\n\n'
        '3. "Verified" badges mean only that specific evidence was reviewed under the platform\'s '
        'policy. They do not guarantee an investor\'s financial capacity, a project\'s success or '
        'the accuracy of every claim.\n\n'
        '4. Draft agreements generated in the app are records of the terms discussed. They are '
        'not legal advice and are not claimed to be legally enforceable contracts.\n\n'
        '5. Owners control who can see their confidential documents, but once access is granted '
        'Orwickle cannot fully prevent copying or screenshots.\n\n'
        '6. You must provide truthful information. Fake profiles, misleading listings, spam and '
        'misuse may lead to suspension of your account.\n\n'
        '7. For security, your session ends after 15 minutes without activity, and your account is '
        'locked for 15 minutes after 5 wrong passwords in a row.',
      ),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  ),
);
