import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';

enum SessionStatus { unknown, unauthenticated, authenticated }

enum LogoutReason { userAction, inactivity, expired }

/// Owns the login session for the whole app.
///
/// * Keeps the access token in memory and the refresh token in secure storage.
/// * Logs the user out after [idleTimeout] (15 minutes) without any touch or request,
///   also when the app comes back from the background after that long.
/// * While the user is active, refreshes the session at least every [_keepAliveInterval], so the
///   backend's own 15-minute inactivity check sees the same activity as the app.
///   Only one refresh runs at a time, because the backend treats a reused refresh token as stolen.
class SessionController extends ChangeNotifier with WidgetsBindingObserver {
  SessionController({
    required this._api,
    required this._storage,
    this.idleTimeout = const Duration(minutes: 15),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const _keepAliveInterval = Duration(minutes: 2);

  final AuthApi _api;
  final TokenStorage _storage;
  final DateTime Function() _now;
  final Duration idleTimeout;

  SessionStatus _status = SessionStatus.unknown;
  AppUser? _user;
  LogoutReason? _lastLogoutReason;

  String? _accessToken;
  DateTime? _accessExpiresAt;
  DateTime? _sessionRenewedAt;
  String? _refreshToken;
  Future<bool>? _refreshInFlight;
  int _generation = 0;   // bumped on logout so late refresh answers are ignored

  Timer? _idleTimer;
  DateTime _lastActivity = DateTime.fromMillisecondsSinceEpoch(0);

  SessionStatus get status => _status;
  AppUser? get user => _user;
  bool get isLoggedIn => _status == SessionStatus.authenticated;

  /// Why the last logout happened; the login screen explains it to the user.
  LogoutReason? get lastLogoutReason => _lastLogoutReason;

  // ---------- start / end ----------

  /// Called once at app start: continues the previous session if it is still alive.
  Future<void> restore() async {
    WidgetsBinding.instance.addObserver(this);
    final saved = await _storage.readRefreshToken();
    if (saved == null) {
      _setUnauthenticated(null);
      return;
    }
    _refreshToken = saved;
    if (!await _refresh()) _setUnauthenticated(null);
  }

  Future<void> login({required String email, required String password}) async =>
      _start(await _api.login(email: email, password: password));

  Future<void> verifyEmail({required String email, required String otp}) async =>
      _start(await _api.verifyEmail(email: email, otp: otp));

  /// Updates the cached user after the profile is saved (name, profile completed).
  void updateUser(AppUser user) {
    _user = user;
    notifyListeners();
  }

  /// The backend ends every other session; this device continues with the new one it returns.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final session = await _api.changePassword(currentPassword: currentPassword, newPassword: newPassword);
    await _apply(session);
    notifyListeners();
  }

  Future<void> logout({LogoutReason reason = LogoutReason.userAction}) async {
    final token = _refreshToken;
    _setUnauthenticated(reason);
    await _storage.clear();
    if (token != null) {
      try {
        await _api.logout(token);
      } on ApiException {
        // already logged out on this device; the server session expires on its own
      }
    }
  }

  Future<void> _start(AuthSession session) async {
    _lastLogoutReason = null;
    await _apply(session);
    _status = SessionStatus.authenticated;
    recordActivity();
    notifyListeners();
  }

  Future<void> _apply(AuthSession session) async {
    _accessToken = session.accessToken;
    _accessExpiresAt = _now().add(session.expiresIn);
    _sessionRenewedAt = _now();
    _refreshToken = session.refreshToken;
    _user = session.user;
    await _storage.saveRefreshToken(session.refreshToken);
  }

  void _setUnauthenticated(LogoutReason? reason) {
    _generation++;
    _idleTimer?.cancel();
    _accessToken = null;
    _accessExpiresAt = null;
    _sessionRenewedAt = null;
    _refreshToken = null;
    _user = null;
    _lastLogoutReason = reason;
    _status = SessionStatus.unauthenticated;
    notifyListeners();
  }

  // ---------- inactivity ----------

  /// Call on every touch and API request. Restarts the 15-minute countdown and
  /// renews the session on the server if that has not happened for a while.
  void recordActivity() {
    if (!isLoggedIn) return;
    _lastActivity = _now();
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, () => logout(reason: LogoutReason.inactivity));

    final renewedAt = _sessionRenewedAt;
    if (renewedAt == null || _now().difference(renewedAt) >= _keepAliveInterval) {
      unawaited(_refresh());
    }
  }

  // Timers do not run while the app is in the background, so check on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isLoggedIn) {
      if (_now().difference(_lastActivity) >= idleTimeout) {
        logout(reason: LogoutReason.inactivity);
      } else {
        recordActivity();
      }
    }
  }

  // ---------- tokens ----------

  /// For ApiClient: a valid access token, or null if the session has ended.
  Future<String?> accessToken({bool forceRefresh = false}) async {
    if (!isLoggedIn && _refreshToken == null) return null;
    final expiresAt = _accessExpiresAt;
    final stale = expiresAt == null || expiresAt.difference(_now()) < const Duration(seconds: 30);
    if (forceRefresh || stale) {
      if (!await _refresh()) return null;
    }
    recordActivity();
    return _accessToken;
  }

  /// Exchanges the refresh token for a new pair. Concurrent callers share one request.
  Future<bool> _refresh() => _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);

  Future<bool> _doRefresh() async {
    final token = _refreshToken;
    if (token == null) return false;
    final generation = _generation;
    try {
      final session = await _api.refresh(token);
      if (generation != _generation) {
        // the user logged out while this was in flight: end the new session too
        unawaited(_api.logout(session.refreshToken).catchError((_) {}));
        return false;
      }
      final wasLoggedIn = isLoggedIn;
      await _apply(session);
      if (!wasLoggedIn) {
        _status = SessionStatus.authenticated;
        recordActivity();
      }
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      // offline: keep the saved session and try again later
      if (e.isNetworkError || generation != _generation) return false;
      await _storage.clear();
      _setUnauthenticated(isLoggedIn ? LogoutReason.expired : null);
      return false;
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
