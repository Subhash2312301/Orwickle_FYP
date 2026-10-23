import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orwickle/core/network/api_client.dart';
import 'package:orwickle/core/validation/validators.dart';
import 'package:orwickle/features/auth/data/auth_models.dart';
import 'package:orwickle/features/auth/session/session_controller.dart';
import 'package:orwickle/features/profile/data/profile_api.dart';
import 'package:orwickle/features/profile/data/profile_models.dart';
import 'package:orwickle/features/profile/screens/profile_edit_screen.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

class FakeProfileApi extends ProfileApi {
  FakeProfileApi(this.role) : super(ApiClient());

  final String role;
  Map<String, dynamic>? savedBody;

  @override
  Future<MyProfile> getMine() async =>
      MyProfile(role: role, email: 'a@b.pk', fullName: 'Ayesha Khan', completed: false, details: const {});

  @override
  Future<List<Category>> categories() async => const [
    Category(id: 'c1', name: 'FinTech'),
    Category(id: 'c2', name: 'EdTech'),
  ];

  @override
  Future<MyProfile> saveMine(Map<String, dynamic> body) async {
    savedBody = body;
    return MyProfile(
      role: role,
      email: 'a@b.pk',
      fullName: body['fullName'] as String,
      completed: true,
      details: const {},
    );
  }
}

Future<SessionController> _sessionAs(String role) async {
  final api = _RoleApi(role);
  final session = SessionController(api: api, storage: MemoryTokenStorage());
  await session.login(email: 'a@b.pk', password: 'x');
  return session;
}

class _RoleApi extends FakeAuthApi {
  _RoleApi(this.role);

  final String role;

  @override
  Future<AuthSession> login({required String email, required String password}) async => AuthSession(
    accessToken: 'a',
    refreshToken: 'r',
    expiresIn: const Duration(minutes: 15),
    user: AppUser(id: 'u', email: email, role: role, fullName: 'Ayesha Khan', emailVerified: true),
  );
}

late SessionController _session;

// Stops the session's 15-minute timer and lets snack bars time out, so no timers outlive the test.
Future<void> _finish(WidgetTester tester) async {
  _session.dispose();
  await tester.pump(const Duration(seconds: 5));
}

Future<FakeProfileApi> _pump(WidgetTester tester, String role) async {
  final profiles = FakeProfileApi(role);
  final session = _session = await _sessionAs(role);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ProfileApi>.value(value: profiles),
        ChangeNotifierProvider.value(value: session),
      ],
      child: const MaterialApp(home: ProfileEditScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return profiles;
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.widgetWithText(FilledButton, 'Save'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  await tester.pumpAndSettle();
}

void main() {
  test('profile validators', () {
    expect(
      Validators.optionalUrl('LinkedIn URL')('linkedin.com/x'),
      'Enter a full LinkedIn URL starting with https://',
    );
    expect(Validators.optionalUrl('LinkedIn URL')('https://www.linkedin.com/in/x'), isNull);
    expect(Validators.optionalUrl('LinkedIn URL')(''), isNull);
    expect(Validators.graduationYear('1800'), 'Enter a valid graduation year');
    expect(Validators.graduationYear('2027'), isNull);
    expect(
      Validators.rangeMax('Maximum budget', () => '500', 'budget')('100'),
      'Maximum budget must be greater than or equal to the minimum',
    );
    expect(Validators.rangeMax('Maximum budget', () => '500', 'budget')('900'), isNull);
  });

  testWidgets('owner form lists every missing required field', (tester) async {
    final api = await _pump(tester, 'owner');
    await _tapSave(tester);

    for (final message in [
      'Headline is required',
      'City is required',
      'University is required',
      'Degree program is required',
      'Add at least one skill',
    ]) {
      expect(find.text(message, skipOffstage: false), findsOneWidget, reason: message);
    }
    expect(api.savedBody, isNull);
    await _finish(tester);
  });

  testWidgets('owner can add skills and save', (tester) async {
    final api = await _pump(tester, 'owner');
    await tester.enterText(find.widgetWithText(TextFormField, 'Headline'), 'CS student building apps');
    await tester.enterText(find.widgetWithText(TextFormField, 'City'), 'Karachi');
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'University'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'University'), 'SZABIST');
    await tester.enterText(find.widgetWithText(TextFormField, 'Degree program'), 'BS CS');
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Skills'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.widgetWithText(TextField, 'Skills'), 'Flutter');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.widgetWithText(InputChip, 'Flutter'), findsOneWidget);

    await _tapSave(tester);
    expect(api.savedBody, isNotNull);
    final details = api.savedBody!['details'] as Map;
    expect(details['skills'], ['Flutter']);
    expect(details['university'], 'SZABIST');
    await _finish(tester);
  });

  testWidgets('investor needs a type, a valid range and an interest', (tester) async {
    await _pump(tester, 'investor');
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Minimum (PKR)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Minimum (PKR)'), '500000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Maximum (PKR)'), '1000');
    await _tapSave(tester);

    expect(find.text('Choose Investor type', skipOffstage: false), findsOneWidget);
    expect(
      find.text('Maximum investment must be greater than or equal to the minimum', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Choose at least one category', skipOffstage: false), findsOneWidget);
    await _finish(tester);
  });
}
