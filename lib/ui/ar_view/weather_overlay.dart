import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/weather_data.dart';
import '../../utils/ar_projection.dart';

class _WindStreamParticle {
  double x;
  double y;
  double length;
  double speed;
  double opacity;

  _WindStreamParticle({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
    required this.opacity,
  });
}

/// True AR Weather Overlay rendering spatial clouds, rain shafts,
/// AR wind direction vectors, and atmospheric particles aligned to compass heading and pitch.
class WeatherOverlay extends StatefulWidget {
  final double userLat;
  final double userLon;
  final List<WeatherGridPoint> gridPoints;
  final double heading;
  final double pitch;
  final WeatherData centerWeather;

  const WeatherOverlay({
    super.key,
    required this.userLat,
    required this.userLon,
    required this.gridPoints,
    required this.heading,
    required this.pitch,
    required this.centerWeather,
  });

  @override
  State<WeatherOverlay> createState() => _WeatherOverlayState();
}

class _WeatherOverlayState extends State<WeatherOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_WindStreamParticle> _windStreams = [];
  final Random _random = Random();
  bool _initializedWindStreams = false;

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

  void _initWindStreams(Size size) {
    if (_initializedWindStreams || size.width == 0) return;
    _initializedWindStreams = true;

    _windStreams.clear();
    for (int i = 0; i < 30; i++) {
      _windStreams.add(_WindStreamParticle(
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height * 0.75,
        length: 50 + _random.nextDouble() * 90,
        speed: 2.5 + _random.nextDouble() * 5.0,
        opacity: 0.35 + _random.nextDouble() * 0.5,
      ));
    }
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
            centerWeather: widget.centerWeather,
            windStreams: _windStreams,
            tick: DateTime.now().millisecondsSinceEpoch / 1000.0,
            onInit: _initWindStreams,
          ),
        );
      },
    );
  }
}

class _ARSpatialWeatherPainter extends CustomPainter {
  final double userLat;
  final double userLon;
  final List<WeatherGridPoint> gridPoints;
  final double heading;
  final double pitch;
  final WeatherData centerWeather;
  final List<_WindStreamParticle> windStreams;
  final double tick;
  final void Function(Size) onInit;

  _ARSpatialWeatherPainter({
    required this.userLat,
    required this.userLon,
    required this.gridPoints,
    required this.heading,
    required this.pitch,
    required this.centerWeather,
    required this.windStreams,
    required this.tick,
    required this.onInit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    onInit(size);
    if (size.width == 0 || size.height == 0) return;

    // 1. Draw Horizon Line
    _drawHorizonGuideLine(canvas, size);

    // 2. Draw AR 3D Wind Compass Pointer & Glowing Flow Streams
    _paintARWindVectorAndFlow(canvas, size);

    // 3. Project each spatial grid point onto AR screen
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

      _drawSpatialWeatherElement(canvas, size, point, projected);
    }
  }

  /// Renders a glowing 3D AR Wind Compass Pointer & dynamic flow particles in the sky.
  void _paintARWindVectorAndFlow(Canvas canvas, Size size) {
    final windDirection = centerWeather.windDirection;
    final relativeWindAngle = (windDirection - heading + 360) % 360;
    final windRad = relativeWindAngle * pi / 180;
    final windDx = sin(windRad);
    final windDy = -cos(windRad) * 0.4;

    // ── A. Glowing Wind Flow Particles ──
    final streamPaint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final effectiveSpeed = max(12.0, centerWeather.windSpeed);

    for (final particle in windStreams) {
      particle.x += windDx * particle.speed * (effectiveSpeed / 15).clamp(0.8, 3.5);
      particle.y += windDy * particle.speed * 0.6;

      if (particle.x > size.width + 120) particle.x = -120;
      if (particle.x < -120) particle.x = size.width + 120;
      if (particle.y > size.height) particle.y = 0;
      if (particle.y < 0) particle.y = size.height * 0.75;

      final start = Offset(particle.x, particle.y);
      final end = Offset(
        particle.x + windDx * particle.length,
        particle.y + windDy * particle.length,
      );

      final streamGradient = ui.Gradient.linear(
        start,
        end,
        [
          const Color(0xFF818CF8).withOpacity(0.0),
          const Color(0xFF38BDF8).withOpacity(particle.opacity * 0.8),
          const Color(0xFF818CF8).withOpacity(0.0),
        ],
      );

      streamPaint.shader = streamGradient;
      canvas.drawLine(start, end, streamPaint);
    }

    // ── B. Floating AR 3D Wind Direction Arrow in Center Sky ──
    final arrowCenterX = (size.width / 2) + (sin(windRad) * (size.width * 0.35));
    final horizonY = (size.height / 2) + (pitch / 37.5) * (size.height / 2);
    final arrowCenterY = (horizonY - 120).clamp(80.0, size.height * 0.45);

    final arrowCenter = Offset(arrowCenterX, arrowCenterY);

    canvas.save();
    canvas.translate(arrowCenter.dx, arrowCenter.dy);
    canvas.rotate(windRad);

    // Draw Arrow Body & Head
    final arrowPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final path = Path();
    path.moveTo(0, -18); // Tip
    path.lineTo(10, 14);
    path.lineTo(0, 8);
    path.lineTo(-10, 14);
    path.close();

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, arrowPaint);

    canvas.restore();
  }

  void _drawHorizonGuideLine(Canvas canvas, Size size) {
    final horizonY = (size.height / 2) + (pitch / 37.5) * (size.height / 2);
    if (horizonY < 0 || horizonY > size.height) return;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 1.2;

    canvas.drawLine(
      Offset(0, horizonY),
      Offset(size.width, horizonY),
      paint,
    );
  }

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
        .clamp(0.3, 0.95);

    // Volumetric cloud billboard
    if (weather.cloudCover > 10) {
      _drawVolumetricCloudBillboard(canvas, pos, baseSize, opacity);
    }

    // Localized rain shaft
    if (weather.rain > 0.05 || weather.weatherCode >= 50) {
      _drawRainShaft(canvas, pos, baseSize, opacity, weather.rain);
    }

    // Spatial AR distance badge
    _drawSpatialDistanceBadge(
      canvas,
      pos + Offset(0, baseSize * 0.45),
      projected.distanceMeters,
      weather,
    );
  }

  void _drawVolumetricCloudBillboard(
    Canvas canvas,
    Offset center,
    double cloudSize,
    double opacity,
  ) {
    final r = cloudSize * 0.4;
    final cloudColor = Colors.white.withOpacity(opacity * 0.85);
    final shadowColor = const Color(0xFF475569).withOpacity(opacity * 0.5);

    final subPuffs = [
      Offset.zero,
      Offset(r * 0.5, -r * 0.2),
      Offset(-r * 0.5, r * 0.05),
      Offset(r * 0.95, r * 0.15),
      Offset(-r * 0.85, r * 0.2),
    ];

    for (final off in subPuffs) {
      final p = center + off;
      final puffR = r * (0.65 + off.dx.abs() / (r * 2.5));

      final shadowPaint = Paint()
        ..shader = ui.Gradient.radial(
          p + Offset(0, puffR * 0.25),
          puffR * 1.1,
          [shadowColor, shadowColor.withOpacity(0)],
        );
      canvas.drawCircle(p + Offset(0, puffR * 0.25), puffR * 1.1, shadowPaint);

      final highlightPaint = Paint()
        ..shader = ui.Gradient.radial(
          p - Offset(puffR * 0.15, puffR * 0.2),
          puffR,
          [cloudColor, cloudColor.withOpacity(0)],
        );
      canvas.drawCircle(p, puffR, highlightPaint);
    }
  }

  void _drawRainShaft(
    Canvas canvas,
    Offset cloudCenter,
    double cloudSize,
    double opacity,
    double rainAmount,
  ) {
    final shaftWidth = cloudSize * 0.85;
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
          const Color(0xFF38BDF8).withOpacity(opacity * 0.6),
          const Color(0xFF0284C7).withOpacity(0.0),
        ],
      );

    canvas.drawRect(shaftRect, rainPaint);
  }

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
          Shadow(color: Colors.black87, blurRadius: 4),
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

    final bgPaint = Paint()..color = const Color(0xFF0F172A).withOpacity(0.65);
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
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
