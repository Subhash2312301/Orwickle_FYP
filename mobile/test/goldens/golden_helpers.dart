import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orwickle/core/theme/app_theme.dart';

/// Phone used for every golden: 390 × 844 logical pixels (a common modern phone).
const goldenPhone = Size(390, 844);

bool _fontsLoaded = false;

/// Loads the real fonts so goldens show Sora / Inter and the Material icons instead of boxes.
/// The app fonts come from assets/google_fonts; the icon font from the Flutter SDK.
Future<void> loadGoldenFonts() async {
  if (_fontsLoaded) return;
  GoogleFonts.config.allowRuntimeFetching = false;
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = root == null ? null : File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons != null && icons.existsSync()) {
    final bytes = icons.readAsBytesSync();
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
  _fontsLoaded = true;
}

/// Pumps [screen] on the golden phone in [theme], with animations off (no shimmer or entrances),
/// waits for the Google Fonts to load, and settles.
Future<void> pumpGolden(WidgetTester tester, Widget Function(ThemeData theme) screen, {required bool dark}) async {
  await loadGoldenFonts();
  tester.view.physicalSize = goldenPhone * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(screen(dark ? AppTheme.dark : AppTheme.light));
  await tester.runAsync(GoogleFonts.pendingFonts);
  await tester.pumpAndSettle();
}

/// Runs [body] once for the light and once for the dark theme; the golden file name gets
/// "_light" / "_dark" appended.
void goldenBothThemes(String name, Future<void> Function(WidgetTester tester, bool dark, String file) body) {
  for (final dark in [false, true]) {
    final file = 'files/${name}_${dark ? 'dark' : 'light'}.png';
    testWidgets('$name (${dark ? 'dark' : 'light'})', (tester) => body(tester, dark, file), tags: ['golden']);
  }
}
