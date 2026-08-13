import 'dart:math';
import 'package:flutter/material.dart';

/// A sleek compass-style indicator showing wind direction relative to
/// the device's current heading.
///
/// Displays as a circular glass ring with an animated arrow pointing
/// in the wind direction.
class WindDirectionIndicator extends StatelessWidget {
  /// Wind angle relative to device heading (0-360 degrees).
  final double relativeWindAngle;

  /// Wind speed label to display in center.
  final String speedLabel;

  /// Direction label (e.g. "NW").
  final String directionLabel;

  const WindDirectionIndicator({
    super.key,
    required this.relativeWindAngle,
    required this.speedLabel,
    required this.directionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(
        painter: _WindCompassPainter(
          angle: relativeWindAngle,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                directionLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              Text(
                speedLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the wind compass ring and arrow.
class _WindCompassPainter extends CustomPainter {
  final double angle;

  _WindCompassPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Outer ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.25);
    canvas.drawCircle(center, radius, ringPaint);

    // Tick marks for N, E, S, W
    for (int i = 0; i < 8; i++) {
      final tickAngle = i * pi / 4;
      final isCardinal = i % 2 == 0;
      final outerR = radius;
      final innerR = radius - (isCardinal ? 8 : 5);

      final tickPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isCardinal ? 2 : 1
        ..color = Colors.white.withOpacity(isCardinal ? 0.5 : 0.3);

      canvas.drawLine(
        Offset(
          center.dx + outerR * sin(tickAngle),
          center.dy - outerR * cos(tickAngle),
        ),
        Offset(
          center.dx + innerR * sin(tickAngle),
          center.dy - innerR * cos(tickAngle),
        ),
        tickPaint,
      );
    }

    // Wind direction arrow
    final arrowAngle = angle * pi / 180;
    final arrowLength = radius - 14;
    final arrowTip = Offset(
      center.dx + arrowLength * sin(arrowAngle),
      center.dy - arrowLength * cos(arrowAngle),
    );

    // Arrow shaft gradient
    final arrowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF6C63FF);
    canvas.drawLine(center, arrowTip, arrowPaint);

    // Arrow tip (dot)
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF6C63FF);
    canvas.drawCircle(arrowTip, 4, dotPaint);

    // Center dot
    final centerDotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.4);
    canvas.drawCircle(center, 3, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _WindCompassPainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}
