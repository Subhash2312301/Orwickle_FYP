import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const Color _navy = Color(0xFF111827);
const Color _navy2 = Color(0xFF1E1B4B);
const Color _deepIndigo = Color(0xFF4F46E5);
const Color _flame = Color(0xFFF59E0B);

/// Navy background of the app icon.
const LinearGradient iconBackground = LinearGradient(
  colors: [_navy, _navy2],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Draws the Orwickle mark (logo A, "orbit rocket"): an open orbit ring with a rocket breaking
/// out of it, into a [size] × [size] square. [onDark] draws a white rocket for dark backgrounds;
/// otherwise the rocket uses the brand gradient. Also used by tool/icon/generate_icon_test.dart.
void paintMark(Canvas canvas, double size, {bool onDark = true}) {
  canvas
    ..save()
    ..scale(size / 512); // the drawing below uses a 512-unit square

  // orbit ring: 700 of its 917 units drawn, gap at the top right where the rocket leaves
  const ring = Rect.fromLTWH(110, 110, 292, 292);
  canvas.drawArc(
    ring,
    -14 * math.pi / 180,
    700 / 146,
    false,
    Paint()
      ..shader = AppTheme.gradient.createShader(ring)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 58
      ..strokeCap = StrokeCap.round,
  );

  // rocket, drawn pointing up around 0,0, then tilted up and to the right
  canvas
    ..translate(322, 192)
    ..rotate(math.pi / 4)
    ..scale(0.92);
  final body = Paint();
  if (onDark) {
    body.color = Colors.white;
  } else {
    body.shader = AppTheme.gradient.createShader(const Rect.fromLTRB(-126, -170, 126, 126));
  }

  canvas
    ..drawPath(
      Path()
        ..moveTo(-34, 84)
        ..quadraticBezierTo(0, 200, 34, 84)
        ..close(),
      Paint()..color = _flame,
    )
    ..drawPath(
      Path()
        ..moveTo(-52, 14)
        ..lineTo(-120, 100)
        ..quadraticBezierTo(-126, 126, -98, 120)
        ..lineTo(-52, 92)
        ..close(),
      body,
    )
    ..drawPath(
      Path()
        ..moveTo(52, 14)
        ..lineTo(120, 100)
        ..quadraticBezierTo(126, 126, 98, 120)
        ..lineTo(52, 92)
        ..close(),
      body,
    )
    ..drawPath(
      Path()
        ..moveTo(0, -170)
        ..cubicTo(66, -122, 80, -24, 62, 84)
        ..lineTo(-62, 84)
        ..cubicTo(-80, -24, -66, -122, 0, -170)
        ..close(),
      body,
    )
    ..drawCircle(const Offset(0, -62), 32, Paint()..color = Colors.white)
    ..drawCircle(const Offset(0, -62), 17, Paint()..color = _deepIndigo)
    ..restore();
}

/// Draws the full app icon (navy rounded square with the mark) into a [size] × [size] square.
void paintIcon(Canvas canvas, double size, {double radius = 112 / 512}) {
  final square = Rect.fromLTWH(0, 0, size, size);
  canvas
    ..drawRRect(
      RRect.fromRectAndRadius(square, Radius.circular(size * radius)),
      Paint()..shader = iconBackground.createShader(square),
    )
    ..save()
    ..translate(size * 0.1, size * 0.1);
  paintMark(canvas, size * 0.8);
  canvas.restore();
}

class _IconPainter extends CustomPainter {
  const _IconPainter();

  @override
  void paint(Canvas canvas, Size size) => paintIcon(canvas, size.shortestSide);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.onDark});

  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) => paintMark(canvas, size.shortestSide, onDark: onDark);

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) => oldDelegate.onDark != onDark;
}

/// The app logo: the orbit-rocket mark on the navy rounded square (same as the launcher icon).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Orwickle logo',
    child: SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _IconPainter()),
    ),
  );
}

/// The mark alone, without the square: for app bars and light or dark surfaces.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32, this.onDark});

  final double size;
  final bool? onDark; // null = follow the theme

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Orwickle logo',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(onDark: onDark ?? Theme.of(context).brightness == Brightness.dark)),
    ),
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
