import 'dart:math' as math;

import 'package:flutter/material.dart';

class WorkProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String centerText;
  final String subText;
  final bool dark;
  final bool isOnBreak;

  const WorkProgressRing({
    super.key,
    required this.progress,
    required this.centerText,
    required this.subText,
    required this.dark,
    this.isOnBreak = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOnBreak ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    final percent = (progress * 100).round().clamp(0, 100);

    return SizedBox(
      width: 76,
      height: 76,
      child: CustomPaint(
        painter: _RingPainter(
          progress: math.max(progress, 0.02),
          color: color,
          trackColor: (dark ? Colors.white : Colors.black).withOpacity(0.1),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: dark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subText,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 5;
    const strokeWidth = 7.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    if (progress > 0) {
      final angle = startAngle + sweepAngle;
      final dotX = center.dx + radius * math.cos(angle);
      final dotY = center.dy + radius * math.sin(angle);
      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dotX, dotY), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
