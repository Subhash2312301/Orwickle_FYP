import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../../features/auth/data/auth_models.dart';
import '../../features/auth/screens/change_password_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/verify_email_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/session/session_controller.dart';
import '../../features/design_system/component_gallery_screen.dart';
import '../../features/home/discover_tab.dart';
import '../../features/home/owner_home_tab.dart';
import '../../features/home/profile_tab.dart';
import '../../features/listings/screens/listing_detail_screen.dart';
import '../../features/listings/screens/listing_form_screen.dart';
import '../../features/listings/screens/my_listings_screen.dart';
import '../../features/profile/screens/profile_edit_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/shell/coming_soon.dart';
import '../../features/system_check/system_check_screen.dart';
import '../motion/transitions.dart';
import '../storage/onboarding_state.dart';
import 'routes.dart';

/// All app routes. Redirects follow the session: while it is being checked → splash,
/// logged out → intro slides on the first start, then welcome (or login after an automatic
/// logout), logged in without a completed profile → profile setup, otherwise → the role's first tab.
/// Pages meant for another role send the user to their own first tab.
///
/// After login the tabs live in one [StatefulShellRoute]: every tab is a branch with its own
/// navigation stack, so switching tabs keeps each one where it was. New tabs (e.g. Chat) are a new
/// branch plus an entry in AppShell's tab list.
GoRouter buildRouter(SessionController session, OnboardingState onboarding) => GoRouter(
  initialLocation: Routes.splash,
  refreshListenable: Listenable.merge([session, onboarding]),
  redirect: (context, state) {
    final location = state.matchedLocation;
    if (location == Routes.designSystem) return null; // developer gallery needs no session
    switch (session.status) {
      case SessionStatus.unknown:
        return location == Routes.splash ? null : Routes.splash;
      case SessionStatus.unauthenticated:
        final reason = session.lastLogoutReason;
        if (!onboarding.seen && reason == null) {
          return location == Routes.onboarding ? null : Routes.onboarding;
        }
        if (Routes.public.contains(location)) return null;
        return reason == LogoutReason.inactivity || reason == LogoutReason.expired ? Routes.login : Routes.welcome;
      case SessionStatus.authenticated:
        final role = session.user?.role;
        if (!(session.user?.profileCompleted ?? true)) {
          return location == Routes.profileSetup ? null : Routes.profileSetup;
        }
        final leftTheGate =
            Routes.public.contains(location) ||
            location == Routes.splash ||
            location == Routes.onboarding ||
            location == Routes.profileSetup;
        if (leftTheGate || !Routes.allowedFor(location, role)) return Routes.homeFor(role);
        return null;
    }
  },
  routes: [
    GoRoute(path: Routes.splash, pageBuilder: (context, state) => fadeThroughPage(state, const SplashScreen())),
    GoRoute(path: Routes.onboarding, pageBuilder: (context, state) => fadeThroughPage(state, const OnboardingScreen())),
    GoRoute(path: Routes.welcome, pageBuilder: (context, state) => fadeThroughPage(state, const WelcomeScreen())),
    GoRoute(
      path: Routes.register,
      builder: (context, state) =>
          RegisterScreen(role: UserRole.fromName(state.uri.queryParameters['role']) ?? UserRole.owner),
    ),
    GoRoute(
      path: Routes.verifyEmail,
      builder: (context, state) => VerifyEmailScreen(email: state.uri.queryParameters['email'] ?? ''),
    ),
    GoRoute(path: Routes.login, builder: (context, state) => const LoginScreen()),
    GoRoute(path: Routes.forgotPassword, builder: (context, state) => const ForgotPasswordScreen()),
    GoRoute(
      path: Routes.resetPassword,
      builder: (context, state) => ResetPasswordScreen(email: state.uri.queryParameters['email'] ?? ''),
    ),
    // developer pages, not part of a normal release build
    if (AppConfig.devTools) GoRoute(path: Routes.systemCheck, builder: (context, state) => const SystemCheckScreen()),
    if (AppConfig.devTools)
      GoRoute(path: Routes.designSystem, builder: (context, state) => const ComponentGalleryScreen()),

    StatefulShellRoute(
      pageBuilder: (context, state, shell) => fadeThroughPage(state, AppShell(navigationShell: shell)),
      navigatorContainerBuilder: (context, shell, children) =>
          FadeThroughBranches(index: shell.currentIndex, children: children),
      branches: [
        // the order is fixed; AppShell picks the branches a role sees
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.home, builder: (context, state) => const OwnerHomeTab())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.myListings, builder: (context, state) => const MyListingsScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.discover, builder: (context, state) => const DiscoverTab())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.saved, builder: (context, state) => const ComingSoonPage(savedFeature))],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.requests,
              builder: (context, state) => ComingSoonPage(requestsFeature(session.user?.role ?? 'owner')),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.profile, builder: (context, state) => const ProfileTab())],
        ),
      ],
    ),

    GoRoute(path: Routes.changePassword, builder: (context, state) => const ChangePasswordScreen()),
    GoRoute(
      path: Routes.profileSetup,
      pageBuilder: (context, state) => fadeThroughPage(state, const ProfileEditScreen(setup: true)),
    ),
    GoRoute(path: Routes.profileEdit, builder: (context, state) => const ProfileEditScreen()),
    // fixed paths before the :id pattern
    GoRoute(path: Routes.newListing, pageBuilder: (context, state) => slideUpPage(state, const ListingFormScreen())),
    GoRoute(
      path: '/listings/:id',
      builder: (context, state) => ListingDetailScreen(listingId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) => ListingFormScreen(listingId: state.pathParameters['id']),
        ),
      ],
    ),
  ],
);
