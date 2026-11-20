import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Animated circular arc progress ring (single or double concentric arc).
class CircularProgressRing extends StatelessWidget {
  const CircularProgressRing({
    super.key,
    required this.progress,
    required this.size,
    required this.centerChild,
    this.strokeWidth = 7,
    this.doubleArc = false,
    this.secondaryProgress = 0,
  });

  final double progress;
  final double size;
  final Widget centerChild;
  final double strokeWidth;
  final bool doubleArc;
  final double secondaryProgress;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final clamped = progress.clamp(0.0, 1.0);
    final clampedSecondary = secondaryProgress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: clamped),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        builder: (context, animatedProgress, _) {
          return CustomPaint(
            painter: _RingPainter(
              progress: animatedProgress,
              secondaryProgress: clampedSecondary,
              doubleArc: doubleArc,
              strokeWidth: strokeWidth,
              trackColor: colors.border.withValues(alpha: 0.45),
              arcColor: colors.primary,
              secondaryArcColor: colors.primary.withValues(alpha: 0.55),
            ),
            child: Center(child: centerChild),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.secondaryProgress,
    required this.doubleArc,
    required this.strokeWidth,
    required this.trackColor,
    required this.arcColor,
    required this.secondaryArcColor,
  });

  final double progress;
  final double secondaryProgress;
  final bool doubleArc;
  final double strokeWidth;
  final Color trackColor;
  final Color arcColor;
  final Color secondaryArcColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, outerRadius, trackPaint);

    if (progress > 0) {
      final arcPaint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        arcPaint,
      );
    }

    if (doubleArc) {
      final innerRadius = outerRadius - strokeWidth - 5;
      if (innerRadius > 8) {
        final innerTrack = Paint()
          ..color = trackColor.withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth - 1.5
          ..strokeCap = StrokeCap.round;
        canvas.drawCircle(center, innerRadius, innerTrack);

        if (secondaryProgress > 0) {
          final innerArc = Paint()
            ..color = secondaryArcColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth - 1.5
            ..strokeCap = StrokeCap.round;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: innerRadius),
            math.pi * 0.75,
            2 * math.pi * secondaryProgress,
            false,
            innerArc,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) {
    return old.progress != progress ||
        old.secondaryProgress != secondaryProgress ||
        old.doubleArc != doubleArc ||
        old.arcColor != arcColor ||
        old.trackColor != trackColor;
  }
}
