import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../auth/session/session_controller.dart';

/// One bottom-navigation tab: which router branch it opens and how it looks.
class ShellTab {
  const ShellTab(this.label, this.icon, this.selectedIcon, this.branch);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Index of the branch in app_router.dart's StatefulShellRoute.
  final int branch;
}

/// Branch indexes, in the order they are declared in app_router.dart.
class Branches {
  const Branches._();

  static const home = 0;
  static const myListings = 1;
  static const profile = 2;
}

/// Tabs per role. Owners: Home, My Listings, Profile. Investors and buyers: Home (account status)
/// and Profile. Admins use the web dashboard: Profile only.
/// A later feature (e.g. discovery) is a new branch plus an entry here.
List<ShellTab> tabsFor(String role) {
  const home = ShellTab('Home', Icons.space_dashboard_outlined, Icons.space_dashboard, Branches.home);
  const profile = ShellTab('Profile', Icons.person_outline, Icons.person, Branches.profile);
  return switch (role) {
    'owner' => const [
      home,
      ShellTab('My Listings', Icons.inventory_2_outlined, Icons.inventory_2, Branches.myListings),
      profile,
    ],
    'investor' || 'buyer' => const [home, profile],
    _ => const [profile],
  };
}

/// The frame after login: the current tab's page and a bottom navigation bar for the role.
/// Tapping the current tab again returns it to its first page.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final role = context.select<SessionController, String?>((s) => s.user?.role);
    if (role == null) return const SizedBox.shrink();
    final tabs = tabsFor(role);
    final selected = tabs.indexWhere((t) => t.branch == navigationShell.currentIndex);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: tabs.length < 2
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.of(context).border)),
              ),
              child: NavigationBar(
                selectedIndex: selected < 0 ? 0 : selected,
                animationDuration: Motion.of(context, Motion.slow),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (i) => navigationShell.goBranch(
                  tabs[i].branch,
                  initialLocation: tabs[i].branch == navigationShell.currentIndex,
                ),
                destinations: [
                  for (final t in tabs)
                    NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label),
                ],
              ),
            ),
    );
  }
}
