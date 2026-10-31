import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orwickle/core/network/api_client.dart';
import 'package:orwickle/core/router/app_router.dart';
import 'package:orwickle/core/router/routes.dart';
import 'package:orwickle/core/storage/onboarding_state.dart';
import 'package:orwickle/core/theme/app_theme.dart';
import 'package:orwickle/features/auth/data/auth_models.dart';
import 'package:orwickle/features/auth/session/session_controller.dart';
import 'package:orwickle/features/home/profile_tab.dart';
import 'package:orwickle/features/listings/data/listing_api.dart';
import 'package:orwickle/features/listings/data/listing_models.dart';
import 'package:orwickle/features/profile/data/profile_api.dart';
import 'package:orwickle/features/profile/data/profile_models.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

class _Profiles extends ProfileApi {
  _Profiles(this.reviewStatus, this.reviewNote) : super(ApiClient());

  final String reviewStatus;
  final String? reviewNote;

  @override
  Future<MyProfile> getMine() async => MyProfile(
    role: 'owner',
    email: 'a@b.pk',
    fullName: 'Sara Ahmed',
    completed: true,
    reviewStatus: reviewStatus,
    reviewNote: reviewNote,
    details: const {},
  );
}

class _Listings extends ListingApi {
  _Listings() : super(ApiClient());

  @override
  Future<List<Listing>> mine() async => const [];
}

class _RoleApi extends FakeAuthApi {
  _RoleApi(this.role, this.approval);

  final String role;
  final String approval;

  @override
  Future<AuthSession> login({required String email, required String password}) async => AuthSession(
    accessToken: 'a',
    refreshToken: 'r',
    expiresIn: const Duration(minutes: 15),
    user: AppUser(
      id: 'u',
      email: email,
      role: role,
      fullName: 'Sara Ahmed',
      emailVerified: true,
      profileCompleted: true,
      approvalStatus: approval,
    ),
  );
}

late GoRouter _router;

/// The real app (router, shell, tabs) for a logged-in user of [role].
Future<SessionController> _pump(WidgetTester tester, String role, {String approval = 'approved', String? note}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final session = SessionController(api: _RoleApi(role, approval), storage: MemoryTokenStorage());
  final onboarding = OnboardingState();
  await onboarding.markSeen();
  await session.login(email: 'a@b.pk', password: 'x');
  _router = buildRouter(session, onboarding);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: onboarding),
        Provider<ProfileApi>.value(value: _Profiles(approval, note)),
        Provider<ListingApi>.value(value: _Listings()),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: _router),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('owners get Home, My Listings and Profile tabs', (tester) async {
    final session = await _pump(tester, 'owner');
    for (final label in ['Home', 'My Listings', 'Profile']) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget);
    }
    expect(find.widgetWithText(NavigationDestination, 'Requests'), findsNothing, reason: 'only phases 1-3');
    expect(find.text('Account under review'), findsNothing, reason: 'approved accounts see no banner');
    session.dispose();
  });

  testWidgets('investors get Home and Profile tabs and see their account status', (tester) async {
    final session = await _pump(tester, 'investor');
    for (final label in ['Home', 'Profile']) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget);
    }
    expect(find.widgetWithText(NavigationDestination, 'My Listings'), findsNothing);
    expect(_router.routerDelegate.currentConfiguration.uri.path, Routes.home);
    expect(find.text('Your account'), findsOneWidget);
    session.dispose();
  });

  testWidgets('a page meant for another role sends the user to their own first tab', (tester) async {
    final session = await _pump(tester, 'buyer');
    _router.go(Routes.myListings);
    await tester.pumpAndSettle();
    expect(_router.routerDelegate.currentConfiguration.uri.path, Routes.home);
    session.dispose();
  });

  testWidgets('logging out asks for confirmation first', (tester) async {
    final session = await _pump(tester, 'investor');
    await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
    await tester.pumpAndSettle();
    final logout = find.widgetWithText(OutlinedButton, 'Log out');
    await tester.scrollUntilVisible(logout, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(logout);
    await tester.pumpAndSettle();
    expect(find.text('Are you sure you want to log out?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(session.user, isNotNull, reason: 'Cancel keeps the user logged in');

    await tester.tap(logout);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();
    expect(session.user, isNull);
    session.dispose();
  });

  testWidgets('a pending account sees the review banner; the logout note is in Profile only', (tester) async {
    final session = await _pump(tester, 'owner', approval: 'pending');
    expect(find.text('Account under review'), findsOneWidget);
    expect(find.textContaining('logged out after'), findsNothing);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
    await tester.pumpAndSettle();
    final note = find.textContaining('logged out after 15 minutes');
    await tester.scrollUntilVisible(
      note,
      200,
      scrollable: find.descendant(of: find.byType(ProfileTab), matching: find.byType(Scrollable)).first,
    );
    expect(note, findsOneWidget);
    session.dispose();
  });

  testWidgets('a request for more information shows the admin note', (tester) async {
    final session = await _pump(tester, 'owner', approval: 'needs_evidence', note: 'Please add your GitHub link.');
    await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Please add your GitHub link.'), findsOneWidget);
    expect(find.text('Update profile'), findsOneWidget);
    session.dispose();
  });
}
