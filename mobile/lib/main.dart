import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/session/session_controller.dart';
import 'features/listings/data/listing_api.dart';
import 'features/profile/data/profile_api.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final authApi = AuthApi(apiClient);
  final session = SessionController(api: authApi, storage: const SecureTokenStorage());
  apiClient.accessTokenProvider = session.accessToken;
  session.restore(); // splash screen shows until this finishes

  runApp(
    OrwickleApp(
      apiClient: apiClient,
      authApi: authApi,
      profileApi: ProfileApi(apiClient),
      listingApi: ListingApi(apiClient),
      session: session,
    ),
  );
}
