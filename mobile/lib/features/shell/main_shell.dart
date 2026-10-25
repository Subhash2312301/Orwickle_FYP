import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/session/session_controller.dart';
import '../home/discover_tab.dart';
import '../home/owner_home_tab.dart';
import '../home/profile_tab.dart';
import '../listings/screens/my_listings_screen.dart';
import 'coming_soon.dart';

/// Bottom-navigation shell after login. Tabs depend on the role:
/// owner → Home, My Listings, Requests, Messages, Profile; investor / buyer → Discover, Requests, Messages, Profile;
/// admin → Profile. Requests and Messages are later-phase features and show a "Coming soon" page.
/// IndexedStack keeps each tab's state (scroll position, loaded data) when switching.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon, this.page, {this.soon = false});

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  final bool soon; // not built yet; the icon carries a small dot
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  List<_Tab> _tabsFor(String role) {
    final upcoming = [
      _Tab('Requests', Icons.handshake_outlined, Icons.handshake, ComingSoonPage(requestsFeature(role)), soon: true),
      const _Tab('Messages', Icons.chat_bubble_outline, Icons.chat_bubble, ComingSoonPage(messagesFeature), soon: true),
    ];
    const profile = _Tab('Profile', Icons.person_outline, Icons.person, ProfileTab());
    return switch (role) {
      'owner' => [
        const _Tab('Home', Icons.home_outlined, Icons.home, OwnerHomeTab()),
        const _Tab('My Listings', Icons.inventory_2_outlined, Icons.inventory_2, MyListingsScreen()),
        ...upcoming,
        profile,
      ],
      'investor' || 'buyer' => [
        const _Tab('Discover', Icons.travel_explore_outlined, Icons.travel_explore, DiscoverTab()),
        ...upcoming,
        profile,
      ],
      _ => const [profile],
    };
  }

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
                  NavigationDestination(
                    icon: Badge(isLabelVisible: t.soon, smallSize: 7, child: Icon(t.icon)),
                    selectedIcon: Icon(t.selectedIcon),
                    label: t.label,
                    tooltip: t.soon ? '${t.label} (coming soon)' : t.label,
                  ),
              ],
            ),
    );
  }
}
