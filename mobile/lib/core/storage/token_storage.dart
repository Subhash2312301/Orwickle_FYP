import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the refresh token in the phone's encrypted storage (Android Keystore / iOS Keychain).
/// The access token is never stored; it lives in memory only.
abstract class TokenStorage {
  Future<String?> readRefreshToken();
  Future<void> saveRefreshToken(String token);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage([this._storage = const FlutterSecureStorage()]);

  static const _refreshTokenKey = 'orwickle_refresh_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> saveRefreshToken(String token) => _storage.write(key: _refreshTokenKey, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _refreshTokenKey);
}
