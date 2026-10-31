import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/widgets.dart';
import '../auth/widgets/form_widgets.dart';
import '../auth/widgets/terms_dialog.dart';

/// Settings: appearance (system / light / dark), account actions, and about with the disclaimer.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themes = context.watch<ThemeController>();
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: const AppAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xxl),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Sizes.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader('Appearance', subtitle: 'Follow the phone, or choose light or dark.'),
                  SegmentedToggle<ThemeMode>(
                    value: themes.mode,
                    onChanged: themes.setMode,
                    segments: const [
                      ToggleSegment(value: ThemeMode.system, label: 'System', icon: Icons.brightness_auto_outlined),
                      ToggleSegment(value: ThemeMode.light, label: 'Light', icon: Icons.light_mode_outlined),
                      ToggleSegment(value: ThemeMode.dark, label: 'Dark', icon: Icons.dark_mode_outlined),
                    ],
                  ),
                  const SectionHeader('Account'),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: Gaps.xs),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.password),
                          title: const Text('Change password'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(Routes.changePassword),
                        ),
                        ListTile(
                          leading: Icon(Icons.logout, color: colors.error),
                          title: Text('Log out', style: TextStyle(color: colors.error)),
                          onTap: () => confirmLogout(context),
                        ),
                      ],
                    ),
                  ),
                  const SectionHeader('About'),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: Gaps.xs),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.gavel_outlined),
                          title: const Text('Terms of Use & Disclaimer'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => showTermsDialog(context),
                        ),
                        ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: const Text('Open-source licences'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => showLicensePage(
                            context: context,
                            applicationName: 'Orwickle',
                            applicationVersion: AppConfig.version,
                            applicationIcon: const Padding(
                              padding: EdgeInsets.all(Gaps.sm),
                              child: BrandLogo(size: 48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const DisclaimerBanner(),
                  const SizedBox(height: Gaps.lg),
                  const Center(child: BrandMark(size: 32)),
                  const SizedBox(height: Gaps.sm),
                  Text(
                    'Orwickle ${AppConfig.version}\nA verified marketplace for student and developer projects.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
