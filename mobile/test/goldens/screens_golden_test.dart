// Golden (screenshot) tests for the key screens, light and dark.
//   Run:     flutter test --tags golden
//   Update:  flutter test --tags golden --update-goldens   (after an intended UI change)
// Images are in test/goldens/files. They are rendered on Windows; other systems can differ by a
// few pixels in text anti-aliasing, so CI should run them on the same OS (or skip --tags golden).

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orwickle/core/network/api_client.dart';
import 'package:orwickle/core/theme/theme_controller.dart';
import 'package:orwickle/features/auth/data/auth_api.dart';
import 'package:orwickle/features/auth/data/auth_models.dart';
import 'package:orwickle/features/auth/screens/login_screen.dart';
import 'package:orwickle/features/auth/screens/welcome_screen.dart';
import 'package:orwickle/features/auth/session/session_controller.dart';
import 'package:orwickle/features/home/owner_home_tab.dart';
import 'package:orwickle/features/listings/data/listing_api.dart';
import 'package:orwickle/features/listings/data/listing_models.dart';
import 'package:orwickle/features/listings/screens/listing_form_screen.dart';
import 'package:orwickle/features/listings/screens/my_listings_screen.dart';
import 'package:orwickle/features/profile/data/profile_api.dart';
import 'package:orwickle/features/profile/data/profile_models.dart';
import 'package:orwickle/features/settings/settings_screen.dart';
import 'package:provider/provider.dart';

import '../fakes.dart';
import 'golden_helpers.dart';

Listing _listing(String id, bool funding, String title, String status, String review, num amount) => Listing(
  id: id,
  listingType: funding ? 'funding' : 'sale',
  categoryId: 'c',
  categoryName: funding ? 'AgriTech' : 'HealthTech',
  title: title,
  shortDescription: 'Soil sensors and a mobile app that water crops only when they need it.',
  techStack: const ['Flutter', 'ESP32'],
  projectStage: 'prototype',
  askingAmount: amount,
  currency: 'PKR',
  coverUrl: null,
  status: status,
  reviewStatus: review,
  ownerName: 'Sara Ahmed',
);

final _mine = [
  _listing('1', true, 'Smart irrigation kit', 'published', 'approved', 1500000),
  _listing('2', false, 'Clinic booking system', 'published', 'pending', 300000),
  _listing('3', true, 'Blood donor network', 'draft', 'unreviewed', 1200000),
];

class _Listings extends ListingApi {
  _Listings() : super(ApiClient());

  @override
  Future<List<Listing>> mine() async => _mine;
}

class _Categories extends ProfileApi {
  _Categories() : super(ApiClient());

  @override
  Future<List<Category>> categories() async => const [Category(id: 'c', name: 'AgriTech')];
}

class _OwnerApi extends FakeAuthApi {
  @override
  Future<AuthSession> login({required String email, required String password}) async => AuthSession(
    accessToken: 'a',
    refreshToken: 'r',
    expiresIn: const Duration(minutes: 15),
    user: const AppUser(
      id: 'u',
      email: 'sara@example.com',
      role: 'owner',
      fullName: 'Sara Ahmed',
      emailVerified: true,
      profileCompleted: true,
      approvalStatus: 'approved',
    ),
  );
}

Future<(Widget Function(ThemeData), SessionController)> _app(Widget screen) async {
  final session = SessionController(api: _OwnerApi(), storage: MemoryTokenStorage());
  await session.login(email: 'sara@example.com', password: 'x');
  return (
    (ThemeData theme) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        Provider<AuthApi>.value(value: FakeAuthApi()),
        Provider<ListingApi>.value(value: _Listings()),
        Provider<ProfileApi>.value(value: _Categories()),
      ],
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: theme, home: screen),
    ),
    session,
  );
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  final screens = <String, Widget>{
    'welcome': const WelcomeScreen(),
    'login': const LoginScreen(),
    'owner_home': const OwnerHomeTab(),
    'my_listings': const MyListingsScreen(),
    'listing_form': const ListingFormScreen(),
    'settings': const SettingsScreen(),
  };

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    goldenBothThemes(name, (tester, dark, file) async {
      final (app, session) = await _app(screen);
      await pumpGolden(tester, app, dark: dark);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile(file));
      session.dispose(); // stops the inactivity timer before the test ends
    });
  }
}
