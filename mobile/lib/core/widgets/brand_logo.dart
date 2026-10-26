import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Draws the Orwickle rocket (tilted up and to the right) into a [size] × [size] square.
/// Also used by tool/icon/generate_icon_test.dart for the launcher icon and splash image.
void paintRocket(Canvas canvas, double size, {Color body = Colors.white, Color window = AppTheme.brand}) {
  final s = size / 1024; // the drawing below uses a 1024-unit square
  canvas
    ..save()
    ..scale(s)
    ..translate(512, 512)
    ..rotate(math.pi / 4)
    ..translate(-512, -512);

  final white = Paint()..color = body;

  // flame
  canvas.drawPath(
    Path()
      ..moveTo(462, 640)
      ..quadraticBezierTo(512, 860, 512, 860)
      ..quadraticBezierTo(512, 860, 562, 640)
      ..close(),
    Paint()..color = const Color(0xFFF59E0B),
  );

  // fins
  canvas
    ..drawPath(
      Path()
        ..moveTo(420, 470)
        ..lineTo(330, 620)
        ..quadraticBezierTo(330, 660, 370, 650)
        ..lineTo(430, 610)
        ..close(),
      white,
    )
    ..drawPath(
      Path()
        ..moveTo(604, 470)
        ..lineTo(694, 620)
        ..quadraticBezierTo(694, 660, 654, 650)
        ..lineTo(594, 610)
        ..close(),
      white,
    );

  // body: pointed nose, rounded sides, flat base
  canvas.drawPath(
    Path()
      ..moveTo(512, 170)
      ..cubicTo(610, 250, 630, 420, 600, 650)
      ..lineTo(424, 650)
      ..cubicTo(394, 420, 414, 250, 512, 170)
      ..close(),
    white,
  );

  // window
  canvas
    ..drawCircle(const Offset(512, 410), 62, Paint()..color = window)
    ..drawCircle(const Offset(512, 410), 30, white)
    ..restore();
}

class _RocketPainter extends CustomPainter {
  const _RocketPainter();

  @override
  void paint(Canvas canvas, Size size) => paintRocket(canvas, size.shortestSide);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The app logo: white rocket on the brand gradient, in a rounded square.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(gradient: AppTheme.gradient, borderRadius: BorderRadius.circular(size * 0.24)),
    child: CustomPaint(painter: const _RocketPainter()),
  );
}

/// "Orwickle" with the tagline, for the splash and welcome screens.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = color ?? theme.colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Orwickle',
          style: theme.textTheme.headlineMedium?.copyWith(color: textColor, fontWeight: FontWeight.w800),
        ),
        Text(
          'Build  ·  Bid  ·  Grow',
          style: theme.textTheme.bodyMedium?.copyWith(color: textColor.withValues(alpha: 0.75), letterSpacing: 2),
        ),
      ],
    );
  }
}
