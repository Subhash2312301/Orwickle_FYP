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
  FakeProfileApi(this.role, {this.documents = const []}) : super(ApiClient());

  final String role;
  final List<String> documents; // document kinds already uploaded
  Map<String, dynamic>? savedBody;

  @override
  Future<MyProfile> getMine() async => MyProfile(
    role: role,
    email: 'a@b.pk',
    fullName: 'Ayesha Khan',
    completed: false,
    details: const {},
    documents: [for (final kind in documents) ProfileDocument(kind: kind, url: null, contentType: 'image/png')],
  );

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

Future<FakeProfileApi> _pump(
  WidgetTester tester,
  String role, {
  List<String> documents = const [],
  bool setup = false,
}) async {
  final profiles = FakeProfileApi(role, documents: documents);
  final session = _session = await _sessionAs(role);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ProfileApi>.value(value: profiles),
        ChangeNotifierProvider.value(value: session),
      ],
      child: MaterialApp(home: ProfileEditScreen(setup: setup)),
    ),
  );
  await tester.pumpAndSettle();
  return profiles;
}

/// Opens one of the four profile steps by tapping its name in the step header.
Future<void> _step(WidgetTester tester, String title) async {
  await tester.tap(find.text(title).first); // the header comes before the step's own section title
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  // close the keyboard and let an earlier snack bar disappear so nothing covers the button
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  final save = find.widgetWithText(FilledButton, 'Save');
  await tester.scrollUntilVisible(save, 300, scrollable: find.byType(Scrollable).first);
  await tester.tap(save);
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
    expect(Validators.requiredUrl('GitHub profile')(''), 'GitHub profile is required');
    expect(
      Validators.requiredUrl('GitHub profile')('github.com/x'),
      'Enter a full GitHub profile starting with https://',
    );
    expect(Validators.requiredUrl('GitHub profile')('https://github.com/x'), isNull);
    expect(
      Validators.rangeMax('Maximum budget', () => '500', 'budget')('100'),
      'Maximum budget must be greater than or equal to the minimum',
    );
    expect(Validators.rangeMax('Maximum budget', () => '500', 'budget')('900'), isNull);
  });

  testWidgets('first-time setup goes step by step; Next checks only the current step', (tester) async {
    final api = await _pump(tester, 'buyer', setup: true);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Submit for review'), findsNothing, reason: 'submit only on the last step');

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 4'), findsOneWidget, reason: 'step 1 has missing fields');
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(find.text('Choose University or Company', skipOffstage: false), findsNothing, reason: 'step 2 not checked');

    await tester.enterText(find.widgetWithText(TextFormField, 'City'), 'Karachi');
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone number'), '03001234567');
    await tester.enterText(find.widgetWithText(TextFormField, 'LinkedIn profile'), 'https://linkedin.com/in/a');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Back'), findsOneWidget);
    expect(api.savedBody, isNull);
    await _finish(tester);
  });

  testWidgets('owner form lists every missing required field; LinkedIn, GitHub and portfolio are required', (
    tester,
  ) async {
    final api = await _pump(tester, 'owner');
    expect(find.text('Graduation year (optional)', skipOffstage: false), findsNothing);
    expect(find.text('Website (optional)', skipOffstage: false), findsOneWidget);
    expect(find.text('City', skipOffstage: false), findsNothing, reason: 'owners have no city');
    await _tapSave(tester);

    for (final message in [
      'Headline is required',
      'Bio is required',
      'LinkedIn profile is required',
      'Choose whether you are a university student',
      'Add at least one skill',
      'GitHub profile is required',
      'Portfolio link is required',
    ]) {
      expect(find.text(message, skipOffstage: false), findsOneWidget, reason: message);
    }
    expect(api.savedBody, isNull);
    await _finish(tester);
  });

  testWidgets('a student owner must give university, degree and the university ID card', (tester) async {
    await _pump(tester, 'owner');
    expect(find.text('University', skipOffstage: false), findsNothing, reason: 'asked only from students');
    await _step(tester, 'Background');
    await tester.tap(find.text('University student'));
    await tester.pumpAndSettle();
    await _tapSave(tester);

    for (final message in [
      'University is required',
      'Degree program is required',
      'Upload the front of your university ID card',
      'Upload the back of your university ID card',
    ]) {
      expect(find.text(message, skipOffstage: false), findsOneWidget, reason: message);
    }
    await _finish(tester);
  });

  testWidgets('an independent developer gives the CNIC instead of university details', (tester) async {
    final api = await _pump(tester, 'owner', documents: ['cnic_front', 'cnic_back']);
    await tester.enterText(find.widgetWithText(TextFormField, 'Headline'), 'Self-taught developer');
    await tester.enterText(find.widgetWithText(TextFormField, 'Bio'), 'I build apps for small shops.');
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'LinkedIn profile'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'LinkedIn profile'), 'https://linkedin.com/in/a');
    await _step(tester, 'Background');
    await tester.tap(find.text('Independent developer'));
    await tester.pumpAndSettle();
    await _step(tester, 'Skills & work');
    await tester.enterText(find.widgetWithText(TextField, 'Skills'), 'Flutter');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'GitHub profile'), 'https://github.com/a');
    await tester.enterText(find.widgetWithText(TextFormField, 'Portfolio link'), 'https://a.dev');
    expect(find.textContaining('university ID card', skipOffstage: false), findsNothing);
    expect(find.text('The front of your CNIC', skipOffstage: false), findsOneWidget);

    await _tapSave(tester);
    expect(api.savedBody, isNotNull);
    final details = api.savedBody!['details'] as Map;
    expect(details['isStudent'], false);
    expect(details['university'], isNull);
    expect(details['skills'], ['Flutter']);
    await _finish(tester);
  });

  testWidgets('investor must give phone, LinkedIn, CNIC, experience, range and documents', (tester) async {
    await _pump(tester, 'investor');
    expect(find.text('PKR'), findsNothing, reason: 'no currency choice');
    expect(find.text('Headline'), findsNothing, reason: 'investors have no headline');
    await _tapSave(tester);

    for (final message in [
      'Phone number is required',
      'LinkedIn profile is required',
      'Choose an investor type',
      'Choose your investment experience',
      'Professional affiliation is required',
      'Choose an investment range',
      'Choose at least one category',
      'CNIC number is required',
      'Upload the front of your CNIC',
      'Upload the back of your CNIC',
    ]) {
      expect(find.text(message, skipOffstage: false), findsOneWidget, reason: message);
    }
    expect(find.text('Company name', skipOffstage: false), findsNothing, reason: 'company fields only for firms');
    expect(find.text('Website (optional)', skipOffstage: false), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('an individual investor proves funds; past investments need proof too', (tester) async {
    await _pump(tester, 'investor');
    await _step(tester, 'Investing');
    await tester.tap(find.text('Investor type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Individual investor').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Investment experience'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1–3 startups').last);
    await tester.pumpAndSettle();

    await _tapSave(tester);
    for (final message in [
      'Upload proof of funds (bank statement, bank letter or tax return)',
      'Upload proof of a past investment',
      'Describe your past investments',
    ]) {
      expect(find.text(message, skipOffstage: false), findsOneWidget, reason: message);
    }
    expect(find.text('Upload your company registration certificate', skipOffstage: false), findsNothing);
    await _finish(tester);
  });

  testWidgets('choosing "Investment firm" asks for company details and the certificate', (tester) async {
    await _pump(tester, 'investor');
    await _step(tester, 'Investing');
    await tester.tap(find.text('Investor type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Investment firm / VC').last);
    await tester.pumpAndSettle();

    expect(find.text('Company email', skipOffstage: false), findsOneWidget);
    await _tapSave(tester);
    expect(find.text('Company email is required for investment firms', skipOffstage: false), findsOneWidget);
    expect(find.text('Upload your company registration certificate', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('proof of funds', skipOffstage: false), findsNothing, reason: 'firms prove the company');
    await _finish(tester);
  });

  testWidgets('phone and CNIC formats are checked; CNIC gets dashes while typing', (tester) async {
    await _pump(tester, 'investor');
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone number'), '12345');
    final cnic = find.widgetWithText(TextFormField, 'CNIC number');
    await _step(tester, 'Verification');
    await tester.enterText(cnic, '4210112345671');
    final typed = tester.widget<EditableText>(find.descendant(of: cnic, matching: find.byType(EditableText)));
    expect(typed.controller.text, '42101-1234567-1');
    await _tapSave(tester);
    expect(find.text('Enter a mobile number like 03001234567', skipOffstage: false), findsOneWidget);
    expect(find.text('CNIC number is required', skipOffstage: false), findsNothing);
    await _finish(tester);
  });

  testWidgets('buyer gives phone and LinkedIn, chooses University or Company; no budget, headline or website', (
    tester,
  ) async {
    await _pump(tester, 'buyer');
    expect(find.text('Headline'), findsNothing);
    expect(find.textContaining('budget'), findsNothing);
    await _tapSave(tester);
    expect(find.text('Choose University or Company', skipOffstage: false), findsOneWidget);
    expect(find.text('Phone number is required', skipOffstage: false), findsOneWidget);
    expect(find.text('LinkedIn profile is required', skipOffstage: false), findsOneWidget);

    await _step(tester, 'Buyer details');
    await tester.tap(find.text('Company'));
    await tester.pumpAndSettle();
    await _tapSave(tester);
    expect(find.text('Company name is required', skipOffstage: false), findsOneWidget);
    expect(find.text('Company email is required', skipOffstage: false), findsOneWidget);

    await _step(tester, 'Buyer details');
    await tester.tap(find.text('University'));
    await tester.pumpAndSettle();
    await _tapSave(tester);
    expect(find.text('Upload the front of your university ID card', skipOffstage: false), findsOneWidget);
    await _finish(tester);
  });
}
