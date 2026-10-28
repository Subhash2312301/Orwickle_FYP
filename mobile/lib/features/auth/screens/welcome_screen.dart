import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_logo.dart';
import '../data/auth_models.dart';
import '../widgets/auth_link_row.dart';

/// First screen for logged-out users: a brand header, then choose a role to sign up, or log in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _icons = {
    UserRole.owner: Icons.lightbulb_outline,
    UserRole.investor: Icons.trending_up,
    UserRole.buyer: Icons.shopping_bag_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + Gaps.xl),
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(Gaps.xl, MediaQuery.paddingOf(context).top + 48, Gaps.xl, Gaps.xxl),
            decoration: const BoxDecoration(
              gradient: AppTheme.gradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(
              children: [
                const BrandLogo(size: 72),
                const SizedBox(height: Gaps.md),
                Text(
                  'Welcome to Orwickle',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: Gaps.xs),
                Text(
                  'A verified marketplace for projects, investors and buyers',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.xl, Gaps.xl, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('How will you use Orwickle?', style: theme.textTheme.titleMedium),
                    const SizedBox(height: Gaps.md),
                    for (final role in UserRole.values)
                      Card(
                        margin: const EdgeInsets.only(bottom: Gaps.md),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.sm),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: colors.primary.withValues(alpha: 0.12),
                            foregroundColor: colors.primary,
                            child: Icon(_icons[role]),
                          ),
                          title: Text(role.label, style: theme.textTheme.titleMedium),
                          subtitle: Text(role.description),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push(Uri(path: Routes.register, queryParameters: {'role': role.name}).toString()),
                        ),
                      ),
                    const SizedBox(height: Gaps.sm),
                    AuthLinkRow(
                      text: 'Already have an account?',
                      action: 'Log in',
                      onPressed: () => context.push(Routes.login),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
