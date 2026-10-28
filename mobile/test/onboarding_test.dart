import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orwickle/core/router/app_router.dart';
import 'package:orwickle/core/storage/onboarding_state.dart';
import 'package:orwickle/core/theme/app_theme.dart';
import 'package:orwickle/features/auth/session/session_controller.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

Future<void> _pumpApp(WidgetTester tester, OnboardingState onboarding) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final session = SessionController(api: FakeAuthApi(), storage: MemoryTokenStorage());
  await session.restore(); // no saved token: logged out
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: onboarding),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: buildRouter(session, onboarding)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // in-memory secure storage, so no platform channel is needed
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('first start shows three intro slides, then the welcome screen', (tester) async {
    final onboarding = OnboardingState();
    await _pumpApp(tester, onboarding);

    expect(find.text('Show your project to the right people'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Find investors and buyers'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Verified and safe'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(onboarding.seen, isTrue);
    expect(find.text('Welcome to Orwickle'), findsOneWidget);
    expect(find.text('How will you use Orwickle?'), findsOneWidget);
  });

  testWidgets('Skip goes straight to the welcome screen', (tester) async {
    final onboarding = OnboardingState();
    await _pumpApp(tester, onboarding);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Orwickle'), findsOneWidget);
  });

  testWidgets('slides and welcome screen fit with large text (accessibility)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpApp(tester, OnboardingState());

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }
    expect(find.text('Welcome to Orwickle'), findsOneWidget); // an overflow would have failed the test
  });

  testWidgets('slides are not shown again once seen', (tester) async {
    final onboarding = OnboardingState();
    await onboarding.markSeen();
    await _pumpApp(tester, onboarding);

    expect(find.text('Show your project to the right people'), findsNothing);
    expect(find.text('Welcome to Orwickle'), findsOneWidget);
  });
}
