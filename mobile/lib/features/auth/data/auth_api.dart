import '../../../core/network/api_client.dart';
import 'auth_models.dart';

/// Calls to /api/auth. Errors arrive as ApiException (see core/network).
class AuthApi {
  AuthApi(this._api);

  final ApiClient _api;

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    required bool acceptTerms,
  }) => _api.post(
    '/auth/register',
    body: {'fullName': fullName, 'email': email, 'password': password, 'role': role.name, 'acceptTerms': acceptTerms},
  );

  Future<AuthSession> verifyEmail({required String email, required String otp}) async =>
      AuthSession.fromJson(await _api.post('/auth/verify-email', body: {'email': email, 'otp': otp}));

  Future<void> resendOtp({required String email, required OtpPurpose purpose}) =>
      _api.post('/auth/resend-otp', body: {'email': email, 'purpose': purpose.apiValue});

  Future<AuthSession> login({required String email, required String password}) async =>
      AuthSession.fromJson(await _api.post('/auth/login', body: {'email': email, 'password': password}));

  Future<AuthSession> refresh(String refreshToken) async =>
      AuthSession.fromJson(await _api.post('/auth/refresh', body: {'refreshToken': refreshToken}));

  Future<void> logout(String refreshToken) => _api.post('/auth/logout', body: {'refreshToken': refreshToken});

  Future<void> forgotPassword(String email) => _api.post('/auth/forgot-password', body: {'email': email});

  Future<void> resetPassword({required String email, required String otp, required String newPassword}) =>
      _api.post('/auth/reset-password', body: {'email': email, 'otp': otp, 'newPassword': newPassword});

  /// Logged in only. Ends every other session and returns a new one for this device.
  Future<AuthSession> changePassword({required String currentPassword, required String newPassword}) async =>
      AuthSession.fromJson(
        await _api.post(
          '/auth/change-password',
          auth: true,
          body: {'currentPassword': currentPassword, 'newPassword': newPassword},
        ),
      );
}
