import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orwickle/core/motion/entrance.dart';
import 'package:orwickle/core/network/api_exception.dart';
import 'package:orwickle/core/theme/app_theme.dart';
import 'package:orwickle/core/widgets/widgets.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(Gaps.lg),
      child: Center(child: child),
    ),
  ),
);

void main() {
  group('AppButton', () {
    testWidgets('calls onPressed and is disabled without it', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(AppButton(label: 'Save', onPressed: () => taps++)));
      await tester.tap(find.text('Save'));
      expect(taps, 1);

      await tester.pumpWidget(_host(const AppButton(label: 'Save', onPressed: null)));
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });

    testWidgets('while loading it shows a spinner, ignores taps and is announced as in progress', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(AppButton(label: 'Save', loading: true, onPressed: () => taps++)));
      await tester.pump(Motion.fast);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 0);
      expect(find.bySemanticsLabel(RegExp('Save, in progress')), findsOneWidget);
    });

    testWidgets('variants map to the right Material buttons', (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              AppButton.secondary(label: 'A', onPressed: () {}),
              AppButton.ghost(label: 'B', onPressed: () {}),
              AppButton.destructive(label: 'C', onPressed: () {}),
            ],
          ),
        ),
      );
      expect(find.widgetWithText(OutlinedButton, 'A'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'B'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'C'), findsOneWidget);
    });
  });

  group('AppTextField', () {
    testWidgets('password field hides the text and can show it', (tester) async {
      final controller = TextEditingController(text: 'Secret1!');
      await tester.pumpWidget(_host(AppTextField(controller: controller, label: 'Password', password: true)));
      EditableText field() => tester.widget<EditableText>(find.byType(EditableText));
      expect(field().obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(field().obscureText, isFalse);
    });

    testWidgets('shows the server error under the field', (tester) async {
      await tester.pumpWidget(
        _host(AppTextField(controller: TextEditingController(), label: 'Email', serverError: 'Email is taken')),
      );
      expect(find.text('Email is taken'), findsOneWidget);
    });
  });

  testWidgets('status chips carry a word and an icon, not just a colour', (tester) async {
    await tester.pumpWidget(_host(StatusChip.status(AppStatus.rejected)));
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.byIcon(AppStatus.rejected.icon), findsOneWidget);
  });

  testWidgets('listing type chips name the type', (tester) async {
    await tester.pumpWidget(
      _host(const Column(children: [ListingTypeChip(isFunding: true), ListingTypeChip(isFunding: false)])),
    );
    expect(find.text('Seeking Funding'), findsOneWidget);
    expect(find.text('Available for Purchase'), findsOneWidget);
  });

  testWidgets('SegmentedToggle reports the tapped segment and marks the selected one', (tester) async {
    bool? picked;
    await tester.pumpWidget(
      _host(
        SegmentedToggle<bool>(
          value: true,
          onChanged: (v) => picked = v,
          segments: const [
            ToggleSegment(value: true, label: 'Funding'),
            ToggleSegment(value: false, label: 'Sales'),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Sales'));
    expect(picked, isFalse);
    expect(
      tester.getSemantics(find.ancestor(of: find.text('Funding'), matching: find.byType(Semantics)).first),
      matchesSemantics(
        isSelected: true,
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        label: 'Funding',
      ),
    );
  });

  testWidgets('StepperProgress shows where the user is and jumps to a tapped step', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      _host(StepperProgress(steps: const ['One', 'Two', 'Three'], current: 1, onStepTapped: (i) => tapped = i)),
    );
    expect(find.text('Step 2 of 3'), findsOneWidget);
    await tester.tap(find.text('Three'));
    expect(tapped, 2);
  });

  testWidgets('ErrorState explains being offline and offers a retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _host(
        SingleChildScrollView(
          child: ErrorState.from(
            const ApiException(code: 'NETWORK_ERROR', message: 'Cannot reach the server.'),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    expect(find.text('You are offline'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('AnimatedCounter ends on the value and announces it', (tester) async {
    await tester.pumpWidget(_host(const AnimatedCounter(value: 12)));
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
    expect(find.bySemanticsLabel('12'), findsOneWidget);
  });

  testWidgets('with reduced motion, entrances and the skeleton shimmer are skipped', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => Column(
            children: [
              const Text('Hello').entrance(context),
              const Skeleton(child: SkeletonBox(height: 10, width: 10)),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(EntranceTransition), findsNothing);
    // no endless shimmer: the tree settles at once
    await tester.pumpAndSettle();
  });

  test('every status has readable text colours in both themes (WCAG AA, 4.5:1)', () {
    double luminance(Color c) => c.computeLuminance();
    double contrast(Color a, Color b) {
      final (hi, lo) = luminance(a) > luminance(b) ? (a, b) : (b, a);
      return (luminance(hi) + 0.05) / (luminance(lo) + 0.05);
    }

    for (final (colors, surface) in [(AppColors.light, Palette.white), (AppColors.dark, Palette.ink900)]) {
      for (final tone in [
        colors.funding,
        colors.sale,
        colors.pending,
        colors.approved,
        colors.rejected,
        colors.verified,
      ]) {
        expect(contrast(tone.fg, surface), greaterThanOrEqualTo(4.5), reason: '${tone.fg} on $surface');
        expect(contrast(tone.fg, tone.bg), greaterThanOrEqualTo(4.5), reason: '${tone.fg} on ${tone.bg}');
      }
      expect(contrast(colors.textMuted, colors.canvas), greaterThanOrEqualTo(4.5));
    }
  });
}
