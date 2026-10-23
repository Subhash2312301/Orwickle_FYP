import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orwickle/core/network/api_exception.dart';
import 'package:orwickle/features/auth/data/auth_api.dart';
import 'package:orwickle/features/auth/data/auth_models.dart';
import 'package:orwickle/features/auth/screens/login_screen.dart';
import 'package:orwickle/features/auth/screens/register_screen.dart';
import 'package:orwickle/features/auth/session/session_controller.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

Widget _wrap(Widget screen, {required FakeAuthApi api, required SessionController session}) => MultiProvider(
      providers: [
        Provider<AuthApi>.value(value: api),
        ChangeNotifierProvider.value(value: session),
      ],
      child: MaterialApp(home: screen),
    );

void main() {
  late FakeAuthApi api;
  late SessionController session;

  setUp(() {
    api = FakeAuthApi();
    session = SessionController(api: api, storage: MemoryTokenStorage());
  });

  testWidgets('login shows field errors before calling the server', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen(), api: api, session: session));
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(session.isLoggedIn, isFalse);
  });

  testWidgets('login shows the server message for a wrong password', (tester) async {
    api.loginError = const ApiException(code: 'INVALID_CREDENTIALS', message: 'Incorrect email or password');
    await tester.pumpWidget(_wrap(const LoginScreen(), api: api, session: session));

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'subhash@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'Wrong1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password'), findsOneWidget);
  });

  testWidgets('register checks every field and ticks password rules live', (tester) async {
    await tester.pumpWidget(_wrap(const RegisterScreen(role: UserRole.investor), api: api, session: session));
    expect(find.text('Signing up as Investor'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret');
    await tester.pump();
    final tick = find.descendant(
      of: find.ancestor(of: find.text('A lowercase letter'), matching: find.byType(Row)),
      matching: find.byIcon(Icons.check_circle),
    );
    expect(tick, findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'other');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();

    expect(find.text('Full name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });
}
