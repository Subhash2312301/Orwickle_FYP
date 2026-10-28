// Draws the Orwickle launcher icon (logo A: orbit rocket on navy) and writes the PNGs
// used by flutter_launcher_icons and flutter_native_splash.
// Run from mobile/:  flutter test tool/icon/generate_icon_test.dart
// Then:              dart run flutter_launcher_icons && dart run flutter_native_splash:create

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orwickle/core/widgets/brand_logo.dart';

const _size = 1024.0;

/// [scale] is the share of the square the mark fills, centred.
void _paint(Canvas canvas, {required bool background, double scale = 0.8}) {
  if (background) {
    paintIcon(canvas, _size, radius: 0); // launchers and iOS cut their own rounded shape
    return;
  }
  final offset = _size * (1 - scale) / 2;
  canvas.translate(offset, offset);
  paintMark(canvas, _size * scale);
}

Future<void> _save(String path, {required bool background, double scale = 0.8}) async {
  final recorder = ui.PictureRecorder();
  _paint(Canvas(recorder), background: background, scale: scale);
  final image = await recorder.endRecording().toImage(_size.toInt(), _size.toInt());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('generate launcher and splash icons', (tester) async {
    await tester.runAsync(() async {
      await _save('assets/icon/icon.png', background: true); // iOS + legacy Android
      await _save('assets/icon/icon_foreground.png', background: false, scale: 0.6); // adaptive icon layer
      await _save('assets/icon/splash.png', background: false, scale: 0.5); // splash screen
    });
  });
}
