import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../data/auth_models.dart';
import '../widgets/auth_link_row.dart';
import '../widgets/auth_scaffold.dart';

/// First screen for logged-out users: choose a role to sign up, or log in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _icons = {
    UserRole.owner: Icons.lightbulb_outline,
    UserRole.investor: Icons.trending_up,
    UserRole.buyer: Icons.shopping_bag_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: false,
      title: 'Welcome to Orwickle',
      subtitle: 'A trusted marketplace for student and developer projects. How will you use Orwickle?',
      children: [
        for (final role in UserRole.values)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(child: Icon(_icons[role])),
              title: Text(role.label),
              subtitle: Text(role.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Uri(path: Routes.register, queryParameters: {'role': role.name}).toString()),
            ),
          ),
        const SizedBox(height: 16),
        AuthLinkRow(text: 'Already have an account?', action: 'Log in', onPressed: () => context.push(Routes.login)),
      ],
    );
  }
}
