import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'chips.dart';

/// Animated success mark: a circle draws itself, then the tick, with a small pop at the end.
/// Drawn with a custom painter (no Lottie file); shown complete straight away with reduced motion.
class SuccessCheck extends StatefulWidget {
  const SuccessCheck({super.key, this.size = 96, this.role = ToneRole.approved});

  final double size;
  final ToneRole role;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck> with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 900);
  late final AnimationController _controller = AnimationController(vsync: this, duration: _duration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.role.resolve(context);
    final pop = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.75, 1, curve: Curves.easeOutBack),
    );
    return Semantics(
      label: 'Success',
      image: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Transform.scale(
          scale: 0.92 + 0.08 * pop.value,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _CheckPainter(progress: _controller.value, color: tone.fg, fill: tone.bg),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress, required this.color, required this.fill});

  final double progress;
  final Color color;
  final Color fill;

  static double _part(double t, double start, double end) => ((t - start) / (end - start)).clamp(0.0, 1.0);

  Path _partOf(Path path, double fraction) {
    final out = Path();
    for (final PathMetric metric in path.computeMetrics()) {
      out.addPath(metric.extractPath(0, metric.length * fraction), Offset.zero);
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(s / 2, s / 2);
    final stroke = s * 0.07;
    final ring = _part(progress, 0, 0.55);
    final tick = _part(progress, 0.45, 0.9);

    canvas.drawCircle(center, s / 2 * ring, Paint()..color = fill);
    final circle = Path()..addArc(Rect.fromCircle(center: center, radius: s / 2 - stroke / 2), -1.5708, 6.2832);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_partOf(circle, ring), paint);

    final check = Path()
      ..moveTo(s * 0.29, s * 0.52)
      ..lineTo(s * 0.44, s * 0.66)
      ..lineTo(s * 0.72, s * 0.37);
    if (tick > 0) canvas.drawPath(_partOf(check, tick), paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.progress != progress || old.color != color || old.fill != fill;
}
