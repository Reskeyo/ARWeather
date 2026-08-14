import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/weather_data.dart';
import '../../utils/ar_projection.dart';

class _WindParticle {
  double x;
  double y;
  double z;
  double length;
  double speed;
  double opacity;

  _WindParticle({
    required this.x,
    required this.y,
    required this.z,
    required this.length,
    required this.speed,
    required this.opacity,
  });
}

class _SnowParticle {
  double x;
  double y;
  double size;
  double speed;
  double drift;
  double opacity;

  _SnowParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.drift,
    required this.opacity,
  });
}

/// Advanced True AR Weather Overlay rendering spatial clouds, rain shafts,
/// snowflakes, 3D AR wind ribbons, and an authentic AR horizon compass HUD.
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
  final List<_WindParticle> _windParticles = [];
  final List<_SnowParticle> _snowParticles = [];
  final Random _random = Random();
  bool _initialized = false;

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

  void _initParticles(Size size) {
    if (_initialized || size.width == 0) return;
    _initialized = true;

    _windParticles.clear();
    for (int i = 0; i < 40; i++) {
      _windParticles.add(_WindParticle(
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height * 0.75,
        z: 0.3 + _random.nextDouble() * 0.7,
        length: 45 + _random.nextDouble() * 90,
        speed: 2.0 + _random.nextDouble() * 5.0,
        opacity: 0.4 + _random.nextDouble() * 0.5,
      ));
    }

    _snowParticles.clear();
    for (int i = 0; i < 60; i++) {
      _snowParticles.add(_SnowParticle(
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height,
        size: 2.5 + _random.nextDouble() * 5.0,
        speed: 1.5 + _random.nextDouble() * 3.0,
        drift: _random.nextDouble() * pi * 2,
        opacity: 0.4 + _random.nextDouble() * 0.5,
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
            windParticles: _windParticles,
            snowParticles: _snowParticles,
            tick: DateTime.now().millisecondsSinceEpoch / 1000.0,
            onInit: _initParticles,
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
  final List<_WindParticle> windParticles;
  final List<_SnowParticle> snowParticles;
  final double tick;
  final void Function(Size) onInit;

  _ARSpatialWeatherPainter({
    required this.userLat,
    required this.userLon,
    required this.gridPoints,
    required this.heading,
    required this.pitch,
    required this.centerWeather,
    required this.windParticles,
    required this.snowParticles,
    required this.tick,
    required this.onInit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    onInit(size);
    if (size.width == 0 || size.height == 0) return;

    // Horizon line position
    final horizonY = (size.height / 2) + (pitch / 37.5) * (size.height / 2);

    // 1. Draw 3D AR Horizon Compass Scale & Cardinal Markers (N, E, S, W)
    _drawARHorizonCompass(canvas, size, horizonY);

    // 2. Draw 3D Wind Direction Stream Ribbons & Vector Arrow
    _drawARWindStreamsAndPointer(canvas, size, horizonY);

    // 3. Project & draw spatial weather elements (Clouds, Rain shafts, Waypoint pins)
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
        maxDistanceMeters: 14000.0,
      );

      if (!projected.isVisible) continue;

      _drawSpatialWeatherElement(canvas, size, point, projected);
    }

    // 4. Draw Falling Snowflakes if in snow condition
    if (centerWeather.weatherCode >= 70 && centerWeather.weatherCode <= 79) {
      _drawSnowfall(canvas, size);
    }
  }

  /// Draws a spatial AR Compass HUD fixed along the horizon line (N, NE, E, SE, S, SW, W, NW).
  void _drawARHorizonCompass(Canvas canvas, Size size, double horizonY) {
    if (horizonY < -50 || horizonY > size.height + 50) return;

    // Horizon glowing line
    final linePaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.22)
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(0, horizonY), Offset(size.width, horizonY), linePaint);

    // Cardinal directions with their degree azimuths
    const cardinals = [
      {'label': 'N', 'deg': 0.0, 'primary': true},
      {'label': 'NE', 'deg': 45.0, 'primary': false},
      {'label': 'E', 'deg': 90.0, 'primary': true},
      {'label': 'SE', 'deg': 135.0, 'primary': false},
      {'label': 'S', 'deg': 180.0, 'primary': true},
      {'label': 'SW', 'deg': 225.0, 'primary': false},
      {'label': 'W', 'deg': 270.0, 'primary': true},
      {'label': 'NW', 'deg': 315.0, 'primary': false},
    ];

    const hFov = 65.0;

    for (final card in cardinals) {
      final deg = card['deg'] as double;
      final label = card['label'] as String;
      final isPrimary = card['primary'] as bool;

      // Calculate relative horizontal angle to user's heading
      double relAngle = (deg - heading + 540) % 360 - 180;
      if (relAngle < -hFov / 2 - 10 || relAngle > hFov / 2 + 10) continue;

      final x = (size.width / 2) + (relAngle / (hFov / 2)) * (size.width / 2);

      // Tick mark
      final tickHeight = isPrimary ? 12.0 : 6.0;
      final tickPaint = Paint()
        ..color = isPrimary
            ? const Color(0xFF38BDF8).withOpacity(0.8)
            : Colors.white.withOpacity(0.4)
        ..strokeWidth = isPrimary ? 2.0 : 1.0;

      canvas.drawLine(
        Offset(x, horizonY - tickHeight),
        Offset(x, horizonY),
        tickPaint,
      );

      // Cardinal Text label
      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: isPrimary ? 13 : 10,
          fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
          color: isPrimary ? const Color(0xFF38BDF8) : Colors.white70,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, horizonY - tickHeight - textPainter.height - 2),
      );
    }
  }

  /// Draws 3D AR Wind Stream Ribbons and a glowing 3D Wind Direction Pointer.
  void _drawARWindStreamsAndPointer(Canvas canvas, Size size, double horizonY) {
    final windDirection = centerWeather.windDirection;
    final relativeWindAngle = (windDirection - heading + 360) % 360;
    final windRad = relativeWindAngle * pi / 180;
    final windDx = sin(windRad);
    final windDy = -cos(windRad) * 0.35;

    // ── Glowing Wind Stream Ribbons ──
    final streamPaint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final effectiveSpeed = max(14.0, centerWeather.windSpeed);

    for (final particle in windParticles) {
      particle.x += windDx * particle.speed * (effectiveSpeed / 15).clamp(1.0, 3.5);
      particle.y += windDy * particle.speed * 0.6;

      if (particle.x > size.width + 150) particle.x = -150;
      if (particle.x < -150) particle.x = size.width + 150;
      if (particle.y > size.height) particle.y = 0;
      if (particle.y < 0) particle.y = size.height * 0.75;

      final start = Offset(particle.x, particle.y);
      final end = Offset(
        particle.x + windDx * particle.length,
        particle.y + windDy * particle.length,
      );

      final gradient = ui.Gradient.linear(
        start,
        end,
        [
          const Color(0xFF818CF8).withOpacity(0.0),
          const Color(0xFF38BDF8).withOpacity(particle.opacity * 0.85),
          const Color(0xFF818CF8).withOpacity(0.0),
        ],
      );

      streamPaint.shader = gradient;
      canvas.drawLine(start, end, streamPaint);
    }

    // ── Center AR 3D Wind Pointer HUD ──
    final pointerX = (size.width / 2) + (sin(windRad) * (size.width * 0.28));
    final pointerY = (horizonY - 100).clamp(90.0, size.height * 0.42);
    final pointerCenter = Offset(pointerX, pointerY);

    canvas.save();
    canvas.translate(pointerCenter.dx, pointerCenter.dy);
    canvas.rotate(windRad);

    // Glowing Arrow
    final arrowPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final path = Path();
    path.moveTo(0, -22); // Tip
    path.lineTo(12, 16);
    path.lineTo(0, 9);
    path.lineTo(-12, 16);
    path.close();

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, arrowPaint);

    canvas.restore();
  }

  void _drawSpatialWeatherElement(
    Canvas canvas,
    Size size,
    WeatherGridPoint point,
    ARProjectedPoint projected,
  ) {
    final weather = point.weather;
    final pos = Offset(projected.x, projected.y);
    final baseSize = 145.0 * projected.scale;
    final opacity = (projected.opacity * (weather.cloudCover / 100).clamp(0.45, 1.0))
        .clamp(0.35, 0.95);

    // Volumetric cloud billboard
    if (weather.cloudCover > 10) {
      _drawVolumetricCloudBillboard(canvas, pos, baseSize, opacity, weather);
    }

    // Localized rain shaft
    if (weather.rain > 0.05 || weather.weatherCode >= 50) {
      _drawRainShaft(canvas, pos, baseSize, opacity, weather.rain);
    }

    // 3D Spatial AR Distance & Condition Badge
    _drawSpatialDistanceBadge(
      canvas,
      pos + Offset(0, baseSize * 0.48),
      projected.distanceMeters,
      weather,
    );
  }

  void _drawVolumetricCloudBillboard(
    Canvas canvas,
    Offset center,
    double cloudSize,
    double opacity,
    WeatherData weather,
  ) {
    final r = cloudSize * 0.4;
    final isStorm = weather.weatherCode >= 60 || weather.weatherCode >= 95;

    final cloudColor = isStorm
        ? const Color(0xFF94A3B8).withOpacity(opacity * 0.85)
        : Colors.white.withOpacity(opacity * 0.88);

    final shadowColor = isStorm
        ? const Color(0xFF334155).withOpacity(opacity * 0.6)
        : const Color(0xFF475569).withOpacity(opacity * 0.45);

    final subPuffs = [
      Offset.zero,
      Offset(r * 0.55, -r * 0.2),
      Offset(-r * 0.55, r * 0.05),
      Offset(r * 1.0, r * 0.15),
      Offset(-r * 0.9, r * 0.2),
    ];

    for (final off in subPuffs) {
      final p = center + off;
      final puffR = r * (0.68 + off.dx.abs() / (r * 2.5));

      final shadowPaint = Paint()
        ..shader = ui.Gradient.radial(
          p + Offset(0, puffR * 0.25),
          puffR * 1.15,
          [shadowColor, shadowColor.withOpacity(0)],
        );
      canvas.drawCircle(p + Offset(0, puffR * 0.25), puffR * 1.15, shadowPaint);

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
    final shaftWidth = cloudSize * 0.9;
    final shaftHeight = 170.0;
    final shaftRect = Rect.fromLTWH(
      cloudCenter.dx - shaftWidth / 2,
      cloudCenter.dy + cloudSize * 0.22,
      shaftWidth,
      shaftHeight,
    );

    final rainPaint = Paint()
      ..shader = ui.Gradient.linear(
        shaftRect.topCenter,
        shaftRect.bottomCenter,
        [
          const Color(0xFF38BDF8).withOpacity(opacity * 0.65),
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
    final text = '${weather.conditionIcon} $km km • ${weather.temperature.round()}°C';

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

    final bgPaint = Paint()..color = const Color(0xFF0F172A).withOpacity(0.7);
    final borderPaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.35)
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

  void _drawSnowfall(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final flake in snowParticles) {
      flake.y += flake.speed;
      flake.x += sin(tick * 1.5 + flake.drift) * 0.8;

      if (flake.y > size.height) {
        flake.y = 0;
        flake.x = Random().nextDouble() * size.width;
      }

      paint.color = Colors.white.withOpacity(flake.opacity);
      canvas.drawCircle(Offset(flake.x, flake.y), flake.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ARSpatialWeatherPainter oldDelegate) => true;
}
