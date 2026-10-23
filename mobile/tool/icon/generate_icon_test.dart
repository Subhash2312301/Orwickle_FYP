// Draws the Orwickle launcher icon (white storefront on brand blue) and writes the PNGs
// used by flutter_launcher_icons and flutter_native_splash.
// Run from mobile/:  flutter test tool/icon/generate_icon_test.dart
// Then:              dart run flutter_launcher_icons && dart run flutter_native_splash:create

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;
const _brand = Color(0xFF1F4E79);
const _awningLight = Color(0xFFBFD7F0);

void _paint(Canvas canvas, {required bool background, double scale = 1}) {
  if (background) {
    canvas.drawRect(const Rect.fromLTWH(0, 0, _size, _size), Paint()..color = _brand);
  }
  canvas
    ..translate(_size / 2, _size / 2)
    ..scale(scale)
    ..translate(-_size / 2, -_size / 2);

  final white = Paint()..color = Colors.white;

  // shop body with a door cut-out
  final body = RRect.fromLTRBAndCorners(300, 430, 724, 730,
      bottomLeft: const Radius.circular(36), bottomRight: const Radius.circular(36));
  final door = RRect.fromLTRBAndCorners(452, 560, 572, 730,
      topLeft: const Radius.circular(60), topRight: const Radius.circular(60));
  canvas.drawPath(
    Path.combine(PathOperation.difference, Path()..addRRect(body), Path()..addRRect(door)),
    white,
  );

  // scalloped awning: four stripes, alternating colours
  const left = 262.0, top = 300.0, stripe = 125.0, height = 150.0;
  for (var i = 0; i < 4; i++) {
    final x = left + i * stripe;
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(x, top, x + stripe, top + height,
          topLeft: Radius.circular(i == 0 ? 40 : 0),
          topRight: Radius.circular(i == 3 ? 40 : 0),
          bottomLeft: const Radius.circular(stripe / 2),
          bottomRight: const Radius.circular(stripe / 2)),
      Paint()..color = i.isEven ? Colors.white : _awningLight,
    );
  }
}

Future<void> _save(String path, {required bool background, double scale = 1}) async {
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
      await _save('assets/icon/icon.png', background: true);                       // iOS + legacy Android
      await _save('assets/icon/icon_foreground.png', background: false, scale: 0.8); // adaptive icon layer
      await _save('assets/icon/splash.png', background: false, scale: 0.6);         // splash screen
    });
  });
}
