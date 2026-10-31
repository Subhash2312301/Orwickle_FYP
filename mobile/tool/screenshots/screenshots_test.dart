// Phone screenshots of every screen, light and dark, for the FYP report.
//   Run from mobile/:  flutter test tool/screenshots --update-goldens
//   Output:            ../docs/screenshots/<theme>/<nn>_<screen>.png  (390 × 844 at 3×)
// Screens run on sample data (no backend), the same way the golden tests do.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orwickle/core/network/api_client.dart';
import 'package:orwickle/core/storage/onboarding_state.dart';
import 'package:orwickle/core/theme/app_theme.dart';
import 'package:orwickle/core/theme/theme_controller.dart';
import 'package:orwickle/features/auth/data/auth_api.dart';
import 'package:orwickle/features/auth/data/auth_models.dart';
import 'package:orwickle/features/auth/screens/forgot_password_screen.dart';
import 'package:orwickle/features/auth/screens/login_screen.dart';
import 'package:orwickle/features/auth/screens/onboarding_screen.dart';
import 'package:orwickle/features/auth/screens/register_screen.dart';
import 'package:orwickle/features/auth/screens/splash_screen.dart';
import 'package:orwickle/features/auth/screens/verify_email_screen.dart';
import 'package:orwickle/features/auth/screens/welcome_screen.dart';
import 'package:orwickle/features/auth/session/session_controller.dart';
import 'package:orwickle/features/design_system/component_gallery_screen.dart';
import 'package:orwickle/features/discover/discover_screen.dart';
import 'package:orwickle/features/discover/saved_screen.dart';
import 'package:orwickle/features/home/owner_home_tab.dart';
import 'package:orwickle/features/home/profile_tab.dart';
import 'package:orwickle/features/listings/data/listing_api.dart';
import 'package:orwickle/features/listings/data/listing_models.dart';
import 'package:orwickle/features/listings/screens/listing_detail_screen.dart';
import 'package:orwickle/features/listings/screens/listing_form_screen.dart';
import 'package:orwickle/features/listings/screens/my_listings_screen.dart';
import 'package:orwickle/features/profile/data/profile_api.dart';
import 'package:orwickle/features/profile/data/profile_models.dart';
import 'package:orwickle/features/profile/screens/profile_edit_screen.dart';
import 'package:orwickle/features/requests/offer_screen.dart';
import 'package:orwickle/features/requests/requests_screen.dart';
import 'package:orwickle/features/settings/settings_screen.dart';
import 'package:provider/provider.dart';

import '../../test/fakes.dart';
import '../../test/goldens/golden_helpers.dart';

// ---------- sample data ----------

Listing _listing(String id, bool funding, String title, String status, String review, num amount, String category) =>
    Listing(
      id: id,
      listingType: funding ? 'funding' : 'sale',
      categoryId: category,
      categoryName: category,
      title: title,
      shortDescription: funding
          ? 'Soil sensors and a mobile app that water crops only when they need it.'
          : 'Appointments, reminders and patient records for small clinics.',
      techStack: const ['Flutter', 'Node.js', 'ESP32'],
      projectStage: funding ? 'prototype' : 'launched',
      askingAmount: amount,
      currency: 'PKR',
      coverUrl: null,
      status: status,
      reviewStatus: review,
      ownerName: 'Sara Ahmed',
    );

final _mine = [
  _listing('1', true, 'Smart irrigation kit', 'published', 'approved', 1500000, 'AgriTech'),
  _listing('2', false, 'Clinic booking system', 'published', 'pending', 300000, 'HealthTech'),
  _listing('3', true, 'Blood donor network', 'draft', 'unreviewed', 1200000, 'HealthTech'),
];

const _confidential = ListingConfidential({
  'equityOfferedPercent': 10,
  'fullDescription':
      'Low-cost moisture sensors report to a phone app over Wi-Fi. The app opens the valve only when the soil '
      'is dry, saving up to 40% of water in our pilot on two farms near Hyderabad.',
  'problemStatement': 'Small farmers over-water because they cannot measure soil moisture.',
  'businessModel': 'One-time kit sale plus a small yearly subscription for the app.',
  'financialSummary': 'Kit cost PKR 9,000; pilot revenue PKR 120,000; break-even at 400 kits.',
  'ipOwnershipNotes': 'Code and hardware design owned by the founders.',
});

class _Listings extends ListingApi {
  _Listings({this.owner = true}) : super(ApiClient());

  final bool owner;

  @override
  Future<List<Listing>> mine() async => _mine;

  @override
  Future<ListingDetail> get(String id) async => ListingDetail(_mine.first, owner ? _confidential : null);
}

class _Profiles extends ProfileApi {
  _Profiles() : super(ApiClient());

  @override
  Future<List<Category>> categories() async => const [
    Category(id: 'AgriTech', name: 'AgriTech'),
    Category(id: 'EdTech', name: 'EdTech'),
  ];

  @override
  Future<MyProfile> getMine() async => const MyProfile(
    role: 'owner',
    email: 'sara@example.com',
    fullName: 'Sara Ahmed',
    headline: 'CS student building AgriTech hardware',
    city: 'Karachi',
    bio: 'I build simple, low-cost devices for small farms.',
    linkedinUrl: 'https://www.linkedin.com/in/sara',
    completed: true,
    reviewStatus: 'approved',
    details: {'isStudent': true, 'university': 'SZABIST', 'degreeProgram': 'BS Computer Science'},
  );
}

class _RoleApi extends FakeAuthApi {
  _RoleApi(this.role);

  final String role;

  @override
  Future<AuthSession> login({required String email, required String password}) async => AuthSession(
    accessToken: 'a',
    refreshToken: 'r',
    expiresIn: const Duration(minutes: 15),
    user: AppUser(
      id: 'u',
      email: 'sara@example.com',
      role: role,
      fullName: role == 'owner' ? 'Sara Ahmed' : 'Ali Khan',
      emailVerified: true,
      profileCompleted: true,
      approvalStatus: 'approved',
    ),
  );
}

// ---------- harness ----------

/// One screenshot: which role is logged in, the screen, and optional steps before the shot.
class _Shot {
  const _Shot(this.name, this.screen, {this.role = 'owner', this.ownerView = true, this.before, this.wait});

  final String name;
  final Widget screen;
  final String role;
  final bool ownerView;
  final Future<void> Function(WidgetTester tester)? before;

  /// Extra fake time for screens that load sample data with a delay (Discover).
  final Duration? wait;
}

Future<void> _settle(WidgetTester tester, [Duration? wait]) async {
  // fixed pumps instead of pumpAndSettle, so a running indicator can never hang the run
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (wait != null) await tester.pump(wait);
  await tester.pump(const Duration(milliseconds: 500));
}

final _shots = <_Shot>[
  const _Shot('01_splash', SplashScreen()),
  const _Shot('02_onboarding_list', OnboardingScreen()),
  _Shot(
    '03_onboarding_discover',
    const OnboardingScreen(),
    before: (tester) async {
      await tester.tap(find.text('Next'));
      await _settle(tester);
    },
  ),
  _Shot(
    '04_onboarding_negotiate',
    const OnboardingScreen(),
    before: (tester) async {
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Next'));
        await _settle(tester);
      }
    },
  ),
  _Shot(
    '05_welcome_role_cards',
    const WelcomeScreen(),
    before: (tester) async {
      await tester.tap(find.text('Investor'));
      await _settle(tester);
    },
  ),
  _Shot(
    '06_register',
    const RegisterScreen(role: UserRole.owner),
    before: (tester) async {
      await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Sara Ahmed');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'sara@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'Orwick@2026!');
      await _settle(tester);
    },
  ),
  const _Shot('07_verify_email', VerifyEmailScreen(email: 'sara@example.com')),
  const _Shot('08_login', LoginScreen()),
  const _Shot('09_forgot_password', ForgotPasswordScreen()),
  const _Shot('10_profile_setup', ProfileEditScreen(setup: true)),
  const _Shot('11_owner_home', OwnerHomeTab()),
  const _Shot('12_my_listings', MyListingsScreen()),
  const _Shot('13_listing_form_type', ListingFormScreen()),
  _Shot(
    '14_listing_form_public',
    const ListingFormScreen(),
    before: (tester) async {
      await tester.tap(find.text('Public preview').first);
      await _settle(tester);
    },
  ),
  _Shot(
    '15_listing_form_confidential',
    const ListingFormScreen(),
    before: (tester) async {
      await tester.tap(find.text('Confidential').first);
      await _settle(tester);
    },
  ),
  _Shot(
    '16_listing_form_review',
    const ListingFormScreen(),
    before: (tester) async {
      await tester.tap(find.text('Review').first);
      await _settle(tester);
    },
  ),
  const _Shot('17_listing_detail_owner', ListingDetailScreen(listingId: '1')),
  const _Shot('18_listing_detail_investor', ListingDetailScreen(listingId: '1'), role: 'investor', ownerView: false),
  const _Shot('19_profile', ProfileTab()),
  const _Shot('20_settings', SettingsScreen()),
  const _Shot('21_discover_funding', DiscoverScreen(), role: 'investor', wait: Duration(seconds: 1)),
  const _Shot('22_discover_sales', DiscoverScreen(), role: 'buyer', wait: Duration(seconds: 1)),
  const _Shot('23_saved', SavedScreen(), role: 'investor'),
  const _Shot('24_requests_access', RequestsScreen()),
  _Shot(
    '25_requests_offers',
    const RequestsScreen(),
    role: 'investor',
    before: (tester) async {
      await tester.tap(find.text('Offers'));
      await _settle(tester);
    },
  ),
  const _Shot('26_offer_timeline', OfferScreen(offerId: 'o1')),
  const _Shot('27_design_system', ComponentGalleryScreen()),
];

void main() {
  // ignore: invalid_use_of_visible_for_testing_member
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    for (final shot in _shots) {
      testWidgets('${shot.name} ($theme)', (tester) async {
        await loadGoldenFonts();
        tester.view.physicalSize = goldenPhone * 3;
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
          disableAnimations: true,
        );
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

        final session = SessionController(api: _RoleApi(shot.role), storage: MemoryTokenStorage());
        await session.login(email: 'sara@example.com', password: 'x');
        final themes = ThemeController();
        await themes.setMode(dark ? ThemeMode.dark : ThemeMode.light);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: session),
              ChangeNotifierProvider.value(value: themes),
              ChangeNotifierProvider(create: (_) => OnboardingState()),
              Provider<AuthApi>.value(value: FakeAuthApi()),
              Provider<ListingApi>.value(value: _Listings(owner: shot.ownerView)),
              Provider<ProfileApi>.value(value: _Profiles()),
            ],
            child: Consumer<ThemeController>(
              builder: (context, t, _) => MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: t.mode,
                home: shot.screen,
              ),
            ),
          ),
        );
        await tester.runAsync(GoogleFonts.pendingFonts);
        await _settle(tester, shot.wait);
        if (shot.before != null) await shot.before!(tester);
        await tester.runAsync(GoogleFonts.pendingFonts);
        await _settle(tester);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../../../docs/screenshots/$theme/${shot.name}.png'),
        );
        session.dispose();
        await tester.pumpWidget(const SizedBox()); // drop the screen (and its timers) before the test ends
        await _settle(tester);
      });
    }
  }
}
