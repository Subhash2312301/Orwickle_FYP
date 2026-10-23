import 'package:orwickle/core/network/api_client.dart';
import 'package:orwickle/core/network/api_exception.dart';
import 'package:orwickle/core/storage/token_storage.dart';
import 'package:orwickle/features/auth/data/auth_api.dart';
import 'package:orwickle/features/auth/data/auth_models.dart';

const testUser = AppUser(
  id: 'u1',
  email: 'subhash@example.com',
  role: 'owner',
  fullName: 'Subhash Rai',
  emailVerified: true,
);

AuthSession sessionNo(int n) => AuthSession(
      accessToken: 'access-$n',
      refreshToken: 'refresh-$n',
      expiresIn: const Duration(minutes: 15),
      user: testUser,
    );

class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this.token]);

  String? token;

  @override
  Future<String?> readRefreshToken() async => token;

  @override
  Future<void> saveRefreshToken(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

/// AuthApi that answers from memory and records what was called.
class FakeAuthApi extends AuthApi {
  FakeAuthApi() : super(ApiClient());

  int refreshCalls = 0;
  final loggedOut = <String>[];
  ApiException? loginError;
  ApiException? refreshError;
  Duration refreshDelay = Duration.zero;

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    if (loginError != null) throw loginError!;
    return sessionNo(1);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    refreshCalls++;
    if (refreshDelay > Duration.zero) await Future<void>.delayed(refreshDelay);
    if (refreshError != null) throw refreshError!;
    return sessionNo(refreshCalls + 1);
  }

  @override
  Future<void> logout(String refreshToken) async => loggedOut.add(refreshToken);

  @override
  Future<AuthSession> changePassword({required String currentPassword, required String newPassword}) async =>
      sessionNo(99);
}
