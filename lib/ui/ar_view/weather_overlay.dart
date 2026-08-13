import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A single cloud particle with position, size, opacity, and speed.
class _CloudParticle {
  double x;
  double y;
  double size;
  double opacity;
  double speed;
  double wobble; // phase offset for gentle vertical oscillation

  _CloudParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.speed,
    required this.wobble,
  });
}

/// A single rain drop particle.
class _RainDrop {
  double x;
  double y;
  double length;
  double speed;
  double opacity;

  _RainDrop({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
    required this.opacity,
  });
}

/// A single snow flake particle.
class _SnowFlake {
  double x;
  double y;
  double size;
  double speed;
  double opacity;
  double drift; // horizontal drift phase

  _SnowFlake({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.drift,
  });
}

/// Animated weather particle overlay that renders clouds, rain, or snow
/// on a CustomPainter canvas.
///
/// The particles drift based on the [windAngle] (relative to device heading)
/// and [windSpeed] to simulate realistic weather effects.
class WeatherOverlay extends StatefulWidget {
  /// Cloud cover percentage (0-100).
  final double cloudCover;

  /// Rainfall amount in mm (0 = no rain).
  final double rain;

  /// WMO weather code to determine effect type.
  final int weatherCode;

  /// Wind angle relative to the device heading (0-360 degrees).
  final double windAngle;

  /// Wind speed in km/h — affects particle velocity.
  final double windSpeed;

  const WeatherOverlay({
    super.key,
    required this.cloudCover,
    required this.rain,
    required this.weatherCode,
    required this.windAngle,
    required this.windSpeed,
  });

  @override
  State<WeatherOverlay> createState() => _WeatherOverlayState();
}

class _WeatherOverlayState extends State<WeatherOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _random = Random();

  // Particle pools
  final List<_CloudParticle> _clouds = [];
  final List<_RainDrop> _rainDrops = [];
  final List<_SnowFlake> _snowFlakes = [];

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

  /// Initializes particle pools based on weather data and canvas size.
  void _initParticles(Size size) {
    if (_initialized) return;
    _initialized = true;

    // Cloud particles — count based on cloud cover
    final cloudCount = (widget.cloudCover / 100 * 25).clamp(0, 25).toInt();
    _clouds.clear();
    for (int i = 0; i < cloudCount; i++) {
      _clouds.add(_CloudParticle(
        x: _random.nextDouble() * size.width * 1.5 - size.width * 0.25,
        y: _random.nextDouble() * size.height * 0.5,
        size: 60 + _random.nextDouble() * 120,
        opacity: 0.15 + _random.nextDouble() * 0.35,
        speed: 0.3 + _random.nextDouble() * 0.7,
        wobble: _random.nextDouble() * pi * 2,
      ));
    }

    // Rain particles
    if (_isRainy) {
      final rainCount = (widget.rain * 30).clamp(20, 200).toInt();
      _rainDrops.clear();
      for (int i = 0; i < rainCount; i++) {
        _rainDrops.add(_RainDrop(
          x: _random.nextDouble() * size.width,
          y: _random.nextDouble() * size.height,
          length: 15 + _random.nextDouble() * 25,
          speed: 4 + _random.nextDouble() * 8,
          opacity: 0.2 + _random.nextDouble() * 0.5,
        ));
      }
    }

    // Snow particles
    if (_isSnowy) {
      final snowCount = 80 + _random.nextInt(60);
      _snowFlakes.clear();
      for (int i = 0; i < snowCount; i++) {
        _snowFlakes.add(_SnowFlake(
          x: _random.nextDouble() * size.width,
          y: _random.nextDouble() * size.height,
          size: 2 + _random.nextDouble() * 5,
          speed: 0.8 + _random.nextDouble() * 2.0,
          opacity: 0.3 + _random.nextDouble() * 0.6,
          drift: _random.nextDouble() * pi * 2,
        ));
      }
    }
  }

  bool get _isRainy =>
      widget.weatherCode >= 50 && widget.weatherCode <= 69 ||
      widget.weatherCode >= 80 && widget.weatherCode <= 84 ||
      widget.weatherCode >= 95;

  bool get _isSnowy =>
      widget.weatherCode >= 70 && widget.weatherCode <= 79 ||
      widget.weatherCode >= 85 && widget.weatherCode <= 86;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _WeatherPainter(
            clouds: _clouds,
            rainDrops: _rainDrops,
            snowFlakes: _snowFlakes,
            windAngle: widget.windAngle,
            windSpeed: widget.windSpeed,
            isRainy: _isRainy,
            isSnowy: _isSnowy,
            tick: DateTime.now().millisecondsSinceEpoch / 1000.0,
            onInit: _initParticles,
          ),
        );
      },
    );
  }
}

/// Custom painter that renders weather particles on the canvas.
class _WeatherPainter extends CustomPainter {
  final List<_CloudParticle> clouds;
  final List<_RainDrop> rainDrops;
  final List<_SnowFlake> snowFlakes;
  final double windAngle;
  final double windSpeed;
  final bool isRainy;
  final bool isSnowy;
  final double tick;
  final void Function(Size) onInit;

  _WeatherPainter({
    required this.clouds,
    required this.rainDrops,
    required this.snowFlakes,
    required this.windAngle,
    required this.windSpeed,
    required this.isRainy,
    required this.isSnowy,
    required this.tick,
    required this.onInit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    onInit(size);

    // Wind vector components (normalized)
    final windRad = windAngle * pi / 180;
    final windDx = sin(windRad) * (windSpeed / 50).clamp(0.2, 2.0);
    final windDy = -cos(windRad) * (windSpeed / 80).clamp(0.1, 1.0);

    _paintClouds(canvas, size, windDx, windDy);

    if (isRainy) {
      _paintRain(canvas, size, windDx);
    }

    if (isSnowy) {
      _paintSnow(canvas, size, windDx);
    }
  }

  /// Renders soft, glowing cloud blobs that drift with the wind.
  void _paintClouds(Canvas canvas, Size size, double windDx, double windDy) {
    for (final cloud in clouds) {
      // Update position
      cloud.x += windDx * cloud.speed * 1.2;
      cloud.y += windDy * cloud.speed * 0.3 +
          sin(tick * 0.5 + cloud.wobble) * 0.3;

      // Wrap around screen edges
      if (cloud.x > size.width + cloud.size) {
        cloud.x = -cloud.size;
      } else if (cloud.x < -cloud.size * 1.5) {
        cloud.x = size.width + cloud.size * 0.5;
      }
      if (cloud.y > size.height * 0.6) {
        cloud.y = -cloud.size * 0.5;
      } else if (cloud.y < -cloud.size) {
        cloud.y = size.height * 0.4;
      }

      // Draw cloud as a series of overlapping gradient circles
      _drawCloudBlob(canvas, cloud);
    }
  }

  /// Draws a single cloud as multiple overlapping soft circles.
  void _drawCloudBlob(Canvas canvas, _CloudParticle cloud) {
    final baseColor = Colors.white.withOpacity(cloud.opacity * 0.6);
    final positions = [
      Offset(cloud.x, cloud.y),
      Offset(cloud.x + cloud.size * 0.3, cloud.y - cloud.size * 0.1),
      Offset(cloud.x + cloud.size * 0.5, cloud.y + cloud.size * 0.05),
      Offset(cloud.x - cloud.size * 0.2, cloud.y + cloud.size * 0.08),
      Offset(cloud.x + cloud.size * 0.15, cloud.y + cloud.size * 0.15),
    ];

    for (int i = 0; i < positions.length; i++) {
      final r = cloud.size * (0.35 + i * 0.05);
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          positions[i],
          r,
          [
            baseColor,
            baseColor.withOpacity(0),
          ],
          [0.0, 1.0],
        );
      canvas.drawCircle(positions[i], r, paint);
    }
  }

  /// Renders falling rain streaks with wind-affected angle.
  void _paintRain(Canvas canvas, Size size, double windDx) {
    final paint = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (final drop in rainDrops) {
      drop.y += drop.speed;
      drop.x += windDx * 2;

      // Wrap
      if (drop.y > size.height + drop.length) {
        drop.y = -drop.length;
        drop.x = Random().nextDouble() * size.width;
      }
      if (drop.x > size.width) drop.x = 0;
      if (drop.x < 0) drop.x = size.width;

      paint.color = Colors.lightBlueAccent.withOpacity(drop.opacity);

      final dx = windDx * drop.length * 0.3;
      canvas.drawLine(
        Offset(drop.x, drop.y),
        Offset(drop.x + dx, drop.y + drop.length),
        paint,
      );
    }
  }

  /// Renders gently falling snowflakes with horizontal drift.
  void _paintSnow(Canvas canvas, Size size, double windDx) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final flake in snowFlakes) {
      flake.y += flake.speed;
      flake.x += sin(tick + flake.drift) * 0.5 + windDx * 0.8;

      // Wrap
      if (flake.y > size.height + flake.size) {
        flake.y = -flake.size;
        flake.x = Random().nextDouble() * size.width;
      }
      if (flake.x > size.width) flake.x = 0;
      if (flake.x < 0) flake.x = size.width;

      paint.color = Colors.white.withOpacity(flake.opacity);
      canvas.drawCircle(Offset(flake.x, flake.y), flake.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter oldDelegate) => true;
}
