import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/session/session_controller.dart';
import '../home/discover_tab.dart';
import '../home/owner_home_tab.dart';
import '../home/profile_tab.dart';
import '../listings/screens/my_listings_screen.dart';

/// Bottom-navigation shell after login. Tabs depend on the role:
/// owner → Home, My Listings, Profile; investor / buyer → Discover, Profile; admin → Profile.
/// IndexedStack keeps each tab's state (scroll position, loaded data) when switching.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon, this.page);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  List<_Tab> _tabsFor(String role) => switch (role) {
    'owner' => const [
      _Tab('Home', Icons.home_outlined, Icons.home, OwnerHomeTab()),
      _Tab('My Listings', Icons.inventory_2_outlined, Icons.inventory_2, MyListingsScreen()),
      _Tab('Profile', Icons.person_outline, Icons.person, ProfileTab()),
    ],
    'investor' || 'buyer' => const [
      _Tab('Discover', Icons.travel_explore_outlined, Icons.travel_explore, DiscoverTab()),
      _Tab('Profile', Icons.person_outline, Icons.person, ProfileTab()),
    ],
    _ => const [_Tab('Profile', Icons.person_outline, Icons.person, ProfileTab())],
  };

  @override
  Widget build(BuildContext context) {
    final role = context.select<SessionController, String?>((s) => s.user?.role);
    if (role == null) return const SizedBox.shrink();
    final tabs = _tabsFor(role);
    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      body: IndexedStack(index: index, children: [for (final t in tabs) t.page]),
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final t in tabs)
                  NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label),
              ],
            ),
    );
  }
}
