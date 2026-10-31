import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion/entrance.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/auth_models.dart';
import '../widgets/auth_link_row.dart';
import '../widgets/terms_dialog.dart';

/// First screen for logged-out users: an ink header with the brand, then the role as three
/// selectable cards and Continue; or log in.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  UserRole? _role;

  void _continue() => context.push(Uri(path: Routes.register, queryParameters: {'role': _role!.name}).toString());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppColors.of(context);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + Gaps.xl),
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(Gaps.xl, top + Gaps.xxl, Gaps.xl, Gaps.xxl),
            decoration: const BoxDecoration(
              gradient: iconBackground,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(Radii.xxl)),
            ),
            child: Column(
              children: [
                const BrandMark(size: 72, onDark: true),
                const SizedBox(height: Gaps.lg),
                Semantics(
                  header: true,
                  child: Text(
                    'Welcome to Orwickle',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge?.copyWith(color: app.onHero),
                  ),
                ),
                const SizedBox(height: Gaps.sm),
                Text(
                  'A verified marketplace where student and developer projects meet investors and buyers.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: app.onHero.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Sizes.maxFormWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.xl, Gaps.xl, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('How will you use Orwickle?', style: theme.textTheme.titleLarge),
                    const SizedBox(height: Gaps.xs),
                    Text('You can only pick one role per account.', style: theme.textTheme.bodySmall),
                    const SizedBox(height: Gaps.lg),
                    for (final (i, role) in UserRole.values.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gaps.md),
                        child: RoleCard(
                          role: role,
                          selected: _role == role,
                          onTap: () => setState(() => _role = role),
                        ).entrance(context, index: i + 1),
                      ),
                    const SizedBox(height: Gaps.sm),
                    AppButton(
                      label: _role == null ? 'Choose a role to continue' : 'Continue as ${_role!.label}',
                      icon: _role == null ? null : Icons.arrow_forward,
                      onPressed: _role == null ? null : _continue,
                    ),
                    const SizedBox(height: Gaps.sm),
                    AuthLinkRow(
                      text: 'Already have an account?',
                      action: 'Log in',
                      onPressed: () => context.push(Routes.login),
                    ),
                    DisclaimerBanner(onLearnMore: () => showTermsDialog(context)),
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

/// A role to sign up as: icon tile in the role's colour, name, one line on what it is for,
/// and a radio-style check. The border and tint animate when selected.
class RoleCard extends StatelessWidget {
  const RoleCard({super.key, required this.role, required this.selected, required this.onTap});

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppColors.of(context);
    final (tone, icon, detail) = switch (role) {
      UserRole.owner => (app.info, Icons.lightbulb_outline, 'Students and independent developers'),
      UserRole.investor => (app.funding, Icons.trending_up, 'Fund early projects for equity'),
      UserRole.buyer => (app.sale, Icons.shopping_bag_outlined, 'Individuals, businesses and agencies'),
    };
    final duration = Motion.of(context, Motion.base);

    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      label: '${role.label}. ${role.description}',
      excludeSemantics: true,
      child: PressScale(
        child: AnimatedContainer(
          duration: duration,
          curve: Motion.standard,
          decoration: BoxDecoration(
            color: selected ? tone.bg : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(
              color: selected ? tone.fg : app.border,
              width: selected ? Sizes.focusRing : Sizes.hairline,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(Radii.lg),
              child: Padding(
                padding: const EdgeInsets.all(Gaps.lg),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: duration,
                      width: Sizes.tapTarget,
                      height: Sizes.tapTarget,
                      decoration: BoxDecoration(
                        color: selected ? theme.colorScheme.surface : tone.bg,
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      child: Icon(icon, color: tone.fg),
                    ),
                    const SizedBox(width: Gaps.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(role.label, style: theme.textTheme.titleMedium),
                          const SizedBox(height: Gaps.xxs),
                          Text(role.description, style: theme.textTheme.bodyMedium),
                          Text(detail, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: Gaps.sm),
                    AnimatedSwitcher(
                      duration: duration,
                      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        selected ? Icons.check_circle : Icons.radio_button_unchecked,
                        key: ValueKey(selected),
                        color: selected ? tone.fg : app.borderStrong,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
