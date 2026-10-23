import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orwickle/core/network/api_client.dart';
import 'package:orwickle/features/listings/data/listing_api.dart';
import 'package:orwickle/features/listings/data/listing_models.dart';
import 'package:orwickle/features/listings/screens/listing_form_screen.dart';
import 'package:orwickle/features/profile/data/profile_api.dart';
import 'package:orwickle/features/profile/data/profile_models.dart';
import 'package:provider/provider.dart';

class _Categories extends ProfileApi {
  _Categories() : super(ApiClient());

  @override
  Future<List<Category>> categories() async => const [Category(id: 'c1', name: 'EdTech')];
}

Future<void> _pumpForm(WidgetTester tester) async {
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<ProfileApi>.value(value: _Categories()),
      // the form never reaches the API in these tests: validation stops it first
      Provider<ListingApi>.value(value: ListingApi(ApiClient())),
    ],
    child: const MaterialApp(home: ListingFormScreen()),
  ));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Save as draft');
  await tester.scrollUntilVisible(button, 400, scrollable: find.byType(Scrollable).first);
  await tester.tap(button);
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));   // let the snack bar time out
}

void main() {
  test('amounts are shown with thousands separators', () {
    expect(formatAmount(1500000, 'PKR'), 'PKR 1,500,000');
    expect(formatAmount(999, 'USD'), 'USD 999');
    expect(formatAmount(null, 'PKR'), '—');
  });

  testWidgets('a funding listing needs the preview fields, full description and equity', (tester) async {
    await _pumpForm(tester);
    await _save(tester);

    for (final message in [
      'Title is required',
      'Short description is required',
      'Choose a category',
      'Choose the project stage',
      'Amount is required',
      'Equity offered is required for funding listings',
      'Full description is required',
    ]) {
      expect(find.text(message, skipOffstage: false), findsOneWidget, reason: message);
    }
    expect(find.text('Describe what the buyer will receive', skipOffstage: false), findsNothing);
  });

  testWidgets('a sale listing asks what the buyer receives instead of equity', (tester) async {
    await _pumpForm(tester);
    await tester.tap(find.text('Available for Purchase'));
    await tester.pumpAndSettle();
    expect(find.text('Asking price (PKR)'), findsOneWidget);

    await _save(tester);
    expect(find.text('Describe what the buyer will receive', skipOffstage: false), findsOneWidget);
    expect(find.text('Equity offered is required for funding listings', skipOffstage: false), findsNothing);
  });
}
