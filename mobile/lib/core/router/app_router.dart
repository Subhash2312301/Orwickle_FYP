import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_models.dart';
import '../../features/auth/screens/change_password_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/verify_email_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/session/session_controller.dart';
import '../../features/home/home_screen.dart';
import '../../features/listings/screens/listing_detail_screen.dart';
import '../../features/listings/screens/listing_form_screen.dart';
import '../../features/listings/screens/my_listings_screen.dart';
import '../../features/profile/screens/profile_edit_screen.dart';
import '../../features/system_check/system_check_screen.dart';
import 'routes.dart';

/// All app routes. Redirects follow the session: while it is being checked → splash,
/// logged out → welcome (or login after an automatic logout), logged in without a
/// completed profile → profile setup, otherwise → home.
GoRouter buildRouter(SessionController session) => GoRouter(
  initialLocation: Routes.splash,
  refreshListenable: session,
  redirect: (context, state) {
    final location = state.matchedLocation;
    switch (session.status) {
      case SessionStatus.unknown:
        return location == Routes.splash ? null : Routes.splash;
      case SessionStatus.unauthenticated:
        if (Routes.public.contains(location)) return null;
        final reason = session.lastLogoutReason;
        return reason == LogoutReason.inactivity || reason == LogoutReason.expired ? Routes.login : Routes.welcome;
      case SessionStatus.authenticated:
        if (!(session.user?.profileCompleted ?? true)) {
          return location == Routes.profileSetup ? null : Routes.profileSetup;
        }
        return Routes.public.contains(location) || location == Routes.splash || location == Routes.profileSetup
            ? Routes.home
            : null;
    }
  },
  routes: [
    GoRoute(path: Routes.splash, builder: (context, state) => const SplashScreen()),
    GoRoute(path: Routes.welcome, builder: (context, state) => const WelcomeScreen()),
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
    GoRoute(path: Routes.systemCheck, builder: (context, state) => const SystemCheckScreen()),
    GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen()),
    GoRoute(path: Routes.changePassword, builder: (context, state) => const ChangePasswordScreen()),
    GoRoute(path: Routes.profileSetup, builder: (context, state) => const ProfileEditScreen(setup: true)),
    GoRoute(path: Routes.profileEdit, builder: (context, state) => const ProfileEditScreen()),
    // fixed paths before the :id pattern
    GoRoute(path: Routes.myListings, builder: (context, state) => const MyListingsScreen()),
    GoRoute(path: Routes.newListing, builder: (context, state) => const ListingFormScreen()),
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
