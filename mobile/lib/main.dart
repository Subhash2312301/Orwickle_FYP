import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/storage/onboarding_state.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/session/session_controller.dart';
import 'features/listings/data/listing_api.dart';
import 'features/profile/data/profile_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false; // fonts are bundled in assets/google_fonts
  LicenseRegistry.addLicense(_fontLicences);

  final apiClient = ApiClient();
  final authApi = AuthApi(apiClient);
  final session = SessionController(api: authApi, storage: const SecureTokenStorage());
  apiClient.accessTokenProvider = session.accessToken;
  final onboarding = OnboardingState();
  final theme = ThemeController();
  // quick local reads: whether the intro slides come first, and light / dark / system
  await Future.wait([onboarding.load(), theme.load()]);
  session.restore(); // splash screen shows until this finishes

  runApp(
    OrwickleApp(
      apiClient: apiClient,
      authApi: authApi,
      profileApi: ProfileApi(apiClient),
      listingApi: ListingApi(apiClient),
      session: session,
      onboarding: onboarding,
      theme: theme,
    ),
  );
}

Stream<LicenseEntry> _fontLicences() async* {
  for (final font in ['Sora', 'Inter']) {
    final text = await rootBundle.loadString('assets/google_fonts/OFL-$font.txt');
    yield LicenseEntryWithLineBreaks([font], text);
  }
}
