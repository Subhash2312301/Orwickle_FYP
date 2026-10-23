import 'package:flutter_test/flutter_test.dart';
import 'package:orwickle/core/network/api_exception.dart';
import 'package:orwickle/features/auth/session/session_controller.dart';

import 'fakes.dart';

void main() {
  late FakeAuthApi api;
  late MemoryTokenStorage storage;
  late DateTime now;
  late SessionController session;

  void advance(Duration d) => now = now.add(d);

  setUp(() {
    api = FakeAuthApi();
    storage = MemoryTokenStorage();
    now = DateTime(2026, 10, 24, 10);
    session = SessionController(api: api, storage: storage, now: () => now);
  });

  testWidgets('without a saved token the user starts logged out', (tester) async {
    await session.restore();
    expect(session.status, SessionStatus.unauthenticated);
    expect(api.refreshCalls, 0);
    session.dispose();
  });

  testWidgets('a saved token restores the session', (tester) async {
    storage.token = 'refresh-0';
    await session.restore();
    expect(session.status, SessionStatus.authenticated);
    expect(session.user!.fullName, 'Subhash Rai');
    expect(storage.token, 'refresh-2'); // rotated
    session.dispose();
  });

  testWidgets('an expired saved token clears storage', (tester) async {
    storage.token = 'refresh-0';
    api.refreshError = const ApiException(code: 'SESSION_EXPIRED', message: 'expired', statusCode: 401);
    await session.restore();
    expect(session.status, SessionStatus.unauthenticated);
    expect(storage.token, isNull);
    session.dispose();
  });

  testWidgets('login saves the refresh token', (tester) async {
    await session.login(email: 'subhash@example.com', password: 'Secret123');
    expect(session.isLoggedIn, isTrue);
    expect(storage.token, 'refresh-1');
    expect(await session.accessToken(), 'access-1');
    session.dispose();
  });

  testWidgets('15 minutes without activity logs the user out', (tester) async {
    await session.login(email: 'subhash@example.com', password: 'Secret123');

    await tester.pump(const Duration(minutes: 14, seconds: 59));
    expect(session.isLoggedIn, isTrue);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(session.isLoggedIn, isFalse);
    expect(session.lastLogoutReason, LogoutReason.inactivity);
    expect(storage.token, isNull);
    expect(api.loggedOut, ['refresh-1']); // server session ended too
    session.dispose();
  });

  testWidgets('activity restarts the 15-minute countdown', (tester) async {
    await session.login(email: 'subhash@example.com', password: 'Secret123');

    await tester.pump(const Duration(minutes: 10));
    advance(const Duration(minutes: 10));
    session.recordActivity();
    await tester.pump(const Duration(minutes: 10));
    expect(session.isLoggedIn, isTrue, reason: 'only 10 minutes since the last touch');

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    expect(session.isLoggedIn, isFalse);
    session.dispose();
  });

  testWidgets('an active user renews the server session every 2 minutes', (tester) async {
    await session.login(email: 'subhash@example.com', password: 'Secret123');

    advance(const Duration(minutes: 1));
    session.recordActivity();
    await tester.pump();
    expect(api.refreshCalls, 0);

    advance(const Duration(minutes: 2));
    session.recordActivity();
    await tester.pump();
    expect(api.refreshCalls, 1);
    session.dispose();
  });

  testWidgets('parallel token requests share one refresh', (tester) async {
    await session.login(email: 'subhash@example.com', password: 'Secret123');
    api.refreshDelay = const Duration(milliseconds: 100);

    final tokens = Future.wait([
      session.accessToken(forceRefresh: true),
      session.accessToken(forceRefresh: true),
      session.accessToken(forceRefresh: true),
    ]);
    await tester.pump(const Duration(milliseconds: 150));
    expect(await tokens, ['access-2', 'access-2', 'access-2']);
    expect(api.refreshCalls, 1);
    session.dispose();
  });

  testWidgets('a server-side expiry logs the user out with a reason', (tester) async {
    await session.login(email: 'subhash@example.com', password: 'Secret123');
    api.refreshError = const ApiException(code: 'SESSION_EXPIRED', message: 'expired', statusCode: 401);

    expect(await session.accessToken(forceRefresh: true), isNull);
    expect(session.isLoggedIn, isFalse);
    expect(session.lastLogoutReason, LogoutReason.expired);
    session.dispose();
  });

  testWidgets('changing the password keeps this device logged in with the new session', (tester) async {
    await session.login(email: 'subhash@example.com', password: 'Orbit#Lane42');
    await session.changePassword(currentPassword: 'Orbit#Lane42', newPassword: 'Maple!River77');
    expect(session.isLoggedIn, isTrue);
    expect(storage.token, 'refresh-99');
    expect(await session.accessToken(), 'access-99');
    session.dispose();
  });

  testWidgets('being offline does not log the user out', (tester) async {
    await session.login(email: 'subhash@example.com', password: 'Secret123');
    api.refreshError = const ApiException(code: 'NETWORK_ERROR', message: 'offline');

    await session.accessToken(forceRefresh: true);
    expect(session.isLoggedIn, isTrue);
    expect(storage.token, 'refresh-1');
    session.dispose();
  });
}
