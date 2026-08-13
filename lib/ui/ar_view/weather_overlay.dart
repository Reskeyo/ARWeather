import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/weather_data.dart';
import '../../utils/ar_projection.dart';

/// True AR Weather Overlay that projects weather elements (clouds, rain shafts, radar markers)
/// at their real-world 3D GPS coordinates relative to the user's camera view.
class WeatherOverlay extends StatefulWidget {
  /// Current user latitude.
  final double userLat;

  /// Current user longitude.
  final double userLon;

  /// Spatial grid of weather points surrounding the user.
  final List<WeatherGridPoint> gridPoints;

  /// Current compass heading (0-360°).
  final double heading;

  /// Current device pitch (-90° to +90°).
  final double pitch;

  const WeatherOverlay({
    super.key,
    required this.userLat,
    required this.userLon,
    required this.gridPoints,
    required this.heading,
    required this.pitch,
  });

  @override
  State<WeatherOverlay> createState() => _WeatherOverlayState();
}

class _WeatherOverlayState extends State<WeatherOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ARSpatialWeatherPainter(
            userLat: widget.userLat,
            userLon: widget.userLon,
            gridPoints: widget.gridPoints,
            heading: widget.heading,
            pitch: widget.pitch,
            tick: DateTime.now().millisecondsSinceEpoch / 1000.0,
          ),
        );
      },
    );
  }
}

/// CustomPainter that projects GPS grid weather data into 2D screen space.
class _ARSpatialWeatherPainter extends CustomPainter {
  final double userLat;
  final double userLon;
  final List<WeatherGridPoint> gridPoints;
  final double heading;
  final double pitch;
  final double tick;

  _ARSpatialWeatherPainter({
    required this.userLat,
    required this.userLon,
    required this.gridPoints,
    required this.heading,
    required this.pitch,
    required this.tick,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (gridPoints.isEmpty || size.width == 0 || size.height == 0) return;

    // Draw horizon radar line for spatial orientation context
    _drawHorizonGuideLine(canvas, size);

    // Project each spatial weather point onto screen
    for (final point in gridPoints) {
      final projected = ARProjection.projectToScreen(
        userLat: userLat,
        userLon: userLon,
        targetLat: point.latitude,
        targetLon: point.longitude,
        targetAltitudeMeters: 1400.0,
        deviceHeading: heading,
        devicePitch: pitch,
        screenSize: size,
        maxDistanceMeters: 12000.0,
      );

      if (!projected.isVisible) continue;

      // Draw spatial weather billboard at projected screen X,Y
      _drawSpatialWeatherElement(canvas, size, point, projected);
    }
  }

  /// Draws a subtle spatial horizon line indicating zero-pitch level.
  void _drawHorizonGuideLine(Canvas canvas, Size size) {
    final horizonY = (size.height / 2) - (pitch / 42.5) * (size.height / 2);
    if (horizonY < 0 || horizonY > size.height) return;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(0, horizonY),
      Offset(size.width, horizonY),
      paint,
    );
  }

  /// Renders a 3D-feeling spatial cloud & weather shaft at projected AR coordinates.
  void _drawSpatialWeatherElement(
    Canvas canvas,
    Size size,
    WeatherGridPoint point,
    ARProjectedPoint projected,
  ) {
    final weather = point.weather;
    final pos = Offset(projected.x, projected.y);
    final baseSize = 140.0 * projected.scale;
    final opacity = (projected.opacity * (weather.cloudCover / 100).clamp(0.4, 1.0))
        .clamp(0.2, 0.9);

    // 1. Draw volumetric cloud billboard at AR coordinates
    if (weather.cloudCover > 10) {
      _drawVolumetricCloudBillboard(canvas, pos, baseSize, opacity);
    }

    // 2. Draw localized rain shaft descending to horizon if raining
    if (weather.rain > 0.05 || weather.weatherCode >= 50) {
      _drawRainShaft(canvas, pos, baseSize, opacity, weather.rain);
    }

    // 3. Draw mini spatial AR distance badge
    _drawSpatialDistanceBadge(
      canvas,
      pos + Offset(0, baseSize * 0.45),
      projected.distanceMeters,
      weather,
    );
  }

  /// Draws a volumetric 3D cloud blob anchored at (pos.x, pos.y).
  void _drawVolumetricCloudBillboard(
    Canvas canvas,
    Offset center,
    double cloudSize,
    double opacity,
  ) {
    final r = cloudSize * 0.4;
    final cloudColor = Colors.white.withOpacity(opacity * 0.75);
    final shadowColor = const Color(0xFF64748B).withOpacity(opacity * 0.4);

    final subPuffs = [
      Offset.zero,
      Offset(r * 0.5, -r * 0.2),
      Offset(-r * 0.5, r * 0.05),
      Offset(r * 0.9, r * 0.15),
      Offset(-r * 0.85, r * 0.2),
    ];

    for (final off in subPuffs) {
      final p = center + off;
      final puffR = r * (0.6 + off.dx.abs() / (r * 2.5));

      // Bottom shadow gradient
      final shadowPaint = Paint()
        ..shader = ui.Gradient.radial(
          p + Offset(0, puffR * 0.2),
          puffR * 1.1,
          [shadowColor, shadowColor.withOpacity(0)],
        );
      canvas.drawCircle(p + Offset(0, puffR * 0.2), puffR * 1.1, shadowPaint);

      // Top soft highlight gradient
      final highlightPaint = Paint()
        ..shader = ui.Gradient.radial(
          p - Offset(puffR * 0.15, puffR * 0.2),
          puffR,
          [cloudColor, cloudColor.withOpacity(0)],
        );
      canvas.drawCircle(p, puffR, highlightPaint);
    }
  }

  /// Draws a rain shaft extending downward from the cloud to the horizon.
  void _drawRainShaft(
    Canvas canvas,
    Offset cloudCenter,
    double cloudSize,
    double opacity,
    double rainAmount,
  ) {
    final shaftWidth = cloudSize * 0.8;
    final shaftHeight = 160.0;
    final shaftRect = Rect.fromLTWH(
      cloudCenter.dx - shaftWidth / 2,
      cloudCenter.dy + cloudSize * 0.2,
      shaftWidth,
      shaftHeight,
    );

    final rainPaint = Paint()
      ..shader = ui.Gradient.linear(
        shaftRect.topCenter,
        shaftRect.bottomCenter,
        [
          const Color(0xFF38BDF8).withOpacity(opacity * 0.45),
          const Color(0xFF0284C7).withOpacity(0.0),
        ],
      );

    canvas.drawRect(shaftRect, rainPaint);
  }

  /// Draws a mini glass distance badge below the cloud element (e.g. "2.4 km").
  void _drawSpatialDistanceBadge(
    Canvas canvas,
    Offset position,
    double distanceMeters,
    WeatherData weather,
  ) {
    final km = (distanceMeters / 1000.0).toStringAsFixed(1);
    final text = '${weather.conditionIcon} $km km';

    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        shadows: [
          Shadow(color: Colors.black54, blurRadius: 4),
        ],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: position,
        width: textPainter.width + 14,
        height: textPainter.height + 6,
      ),
      const Radius.circular(10),
    );

    final bgPaint = Paint()..color = Colors.black.withOpacity(0.45);
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(bgRect, bgPaint);
    canvas.drawRRect(bgRect, borderPaint);

    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _ARSpatialWeatherPainter oldDelegate) => true;
}
