import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A volumetric cloud particle with 3D depth properties.
class _CloudParticle {
  double x;
  double y;
  double z; // Depth factor (0.3 = far away, 1.0 = close foreground)
  double size;
  double opacity;
  double speed;
  double wobble;

  _CloudParticle({
    required this.x,
    required this.y,
    required this.z,
    required this.size,
    required this.opacity,
    required this.speed,
    required this.wobble,
  });
}

/// A rain drop particle.
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

/// A snowflake particle.
class _SnowFlake {
  double x;
  double y;
  double size;
  double speed;
  double opacity;
  double drift;

  _SnowFlake({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.drift,
  });
}

/// Floating atmospheric dust/sparkle particle for sunny/windy weather.
class _DustParticle {
  double x;
  double y;
  double size;
  double opacity;
  double speed;

  _DustParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.speed,
  });
}

/// Animated 3D AR Weather particle overlay.
///
/// Renders volumetric clouds, rain streaks, snow flakes, and atmospheric dust
/// that react dynamically to compass orientation and real-world wind direction.
class WeatherOverlay extends StatefulWidget {
  /// Cloud cover percentage (0-100).
  final double cloudCover;

  /// Rainfall amount in mm.
  final double rain;

  /// WMO weather condition code.
  final int weatherCode;

  /// Wind angle relative to device heading (0-360 degrees).
  final double windAngle;

  /// Wind speed in km/h.
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

  final List<_CloudParticle> _clouds = [];
  final List<_RainDrop> _rainDrops = [];
  final List<_SnowFlake> _snowFlakes = [];
  final List<_DustParticle> _dust = [];

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

  @override
  void didUpdateWidget(WeatherOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cloudCover != widget.cloudCover ||
        oldWidget.weatherCode != widget.weatherCode) {
      _initialized = false; // Re-initialize particle counts on weather change
    }
  }

  void _initParticles(Size size) {
    if (_initialized || size.width == 0 || size.height == 0) return;
    _initialized = true;

    // 1. Cloud particles — Ensure ALWAYS at least 12 cloud blobs for rich AR view
    final cloudCount = max(12, (widget.cloudCover / 100 * 24).round());
    _clouds.clear();
    for (int i = 0; i < cloudCount; i++) {
      final z = 0.3 + _random.nextDouble() * 0.7; // Depth
      _clouds.add(_CloudParticle(
        x: _random.nextDouble() * (size.width + 300) - 150,
        y: _random.nextDouble() * size.height * 0.55 - 40,
        z: z,
        size: (120 + _random.nextDouble() * 160) * z,
        opacity: 0.35 + _random.nextDouble() * 0.45,
        speed: (0.4 + _random.nextDouble() * 0.8) * z,
        wobble: _random.nextDouble() * pi * 2,
      ));
    }

    // Sort by depth (far clouds drawn first)
    _clouds.sort((a, b) => a.z.compareTo(b.z));

    // 2. Rain particles
    if (_isRainy) {
      final rainCount = max(40, (widget.rain * 40).clamp(30, 220).toInt());
      _rainDrops.clear();
      for (int i = 0; i < rainCount; i++) {
        _rainDrops.add(_RainDrop(
          x: _random.nextDouble() * size.width,
          y: _random.nextDouble() * size.height,
          length: 18 + _random.nextDouble() * 28,
          speed: 6 + _random.nextDouble() * 10,
          opacity: 0.35 + _random.nextDouble() * 0.55,
        ));
      }
    }

    // 3. Snow particles
    if (_isSnowy) {
      _snowFlakes.clear();
      for (int i = 0; i < 90; i++) {
        _snowFlakes.add(_SnowFlake(
          x: _random.nextDouble() * size.width,
          y: _random.nextDouble() * size.height,
          size: 3 + _random.nextDouble() * 6,
          speed: 1.0 + _random.nextDouble() * 2.5,
          opacity: 0.4 + _random.nextDouble() * 0.5,
          drift: _random.nextDouble() * pi * 2,
        ));
      }
    }

    // 4. Ambient atmospheric dust/sparkles (adds AR life to sunny/windy scenes)
    _dust.clear();
    for (int i = 0; i < 35; i++) {
      _dust.add(_DustParticle(
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height,
        size: 1.5 + _random.nextDouble() * 3.0,
        opacity: 0.2 + _random.nextDouble() * 0.5,
        speed: 0.3 + _random.nextDouble() * 0.7,
      ));
    }
  }

  bool get _isRainy =>
      widget.rain > 0.1 ||
      (widget.weatherCode >= 50 && widget.weatherCode <= 69) ||
      (widget.weatherCode >= 80 && widget.weatherCode <= 84) ||
      widget.weatherCode >= 95;

  bool get _isSnowy =>
      (widget.weatherCode >= 70 && widget.weatherCode <= 79) ||
      (widget.weatherCode >= 85 && widget.weatherCode <= 86);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ARWeatherPainter(
            clouds: _clouds,
            rainDrops: _rainDrops,
            snowFlakes: _snowFlakes,
            dust: _dust,
            windAngle: widget.windAngle,
            windSpeed: max(10.0, widget.windSpeed),
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

/// CustomPainter rendering 3D-feeling volumetric clouds and weather particles.
class _ARWeatherPainter extends CustomPainter {
  final List<_CloudParticle> clouds;
  final List<_RainDrop> rainDrops;
  final List<_SnowFlake> snowFlakes;
  final List<_DustParticle> dust;
  final double windAngle;
  final double windSpeed;
  final bool isRainy;
  final bool isSnowy;
  final double tick;
  final void Function(Size) onInit;

  _ARWeatherPainter({
    required this.clouds,
    required this.rainDrops,
    required this.snowFlakes,
    required this.dust,
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

    final windRad = windAngle * pi / 180;
    final windDx = sin(windRad) * (windSpeed / 30).clamp(0.3, 2.5);
    final windDy = -cos(windRad) * (windSpeed / 60).clamp(0.1, 0.8);

    // 1. Draw volumetric 3D clouds
    _paintVolumetricClouds(canvas, size, windDx, windDy);

    // 2. Draw atmospheric dust / ambient wind particles
    _paintAtmosphericDust(canvas, size, windDx);

    // 3. Draw rain / snow if active
    if (isRainy) _paintRain(canvas, size, windDx);
    if (isSnowy) _paintSnow(canvas, size, windDx);
  }

  void _paintVolumetricClouds(
    Canvas canvas,
    Size size,
    double windDx,
    double windDy,
  ) {
    for (final cloud in clouds) {
      // Position update with depth factor
      cloud.x += windDx * cloud.speed;
      cloud.y += windDy * cloud.speed * 0.2 + sin(tick * 0.8 + cloud.wobble) * 0.25;

      // Screen wrapping
      if (cloud.x > size.width + cloud.size) {
        cloud.x = -cloud.size * 1.5;
      } else if (cloud.x < -cloud.size * 1.5) {
        cloud.x = size.width + cloud.size;
      }

      if (cloud.y > size.height * 0.6) {
        cloud.y = -cloud.size * 0.5;
      } else if (cloud.y < -cloud.size * 0.8) {
        cloud.y = size.height * 0.45;
      }

      _drawSingleVolumetricCloud(canvas, cloud);
    }
  }

  /// Draws a soft 3D volumetric cloud blob with highlight and shadow depth.
  void _drawSingleVolumetricCloud(Canvas canvas, _CloudParticle cloud) {
    final center = Offset(cloud.x, cloud.y);
    final radius = cloud.size * 0.5;

    // Sub-puffs forming a fluffy cloud shape
    final offsets = [
      Offset.zero,
      Offset(radius * 0.45, -radius * 0.15),
      Offset(-radius * 0.45, radius * 0.05),
      Offset(radius * 0.8, radius * 0.15),
      Offset(-radius * 0.75, radius * 0.2),
      Offset(radius * 0.2, radius * 0.25),
    ];

    // Base cloud color (soft volumetric white with slight cool tint)
    final cloudColor = Colors.white.withOpacity(cloud.opacity * 0.7);
    final shadowColor = const Color(0xFF94A3B8).withOpacity(cloud.opacity * 0.35);

    for (final off in offsets) {
      final pos = center + off;
      final r = radius * (0.55 + off.dx.abs() / (radius * 3));

      // Bottom shadow gradient for 3D depth
      final shadowPaint = Paint()
        ..shader = ui.Gradient.radial(
          pos + Offset(0, r * 0.25),
          r * 1.1,
          [shadowColor, shadowColor.withOpacity(0)],
        );
      canvas.drawCircle(pos + Offset(0, r * 0.25), r * 1.1, shadowPaint);

      // Top soft highlight gradient
      final highlightPaint = Paint()
        ..shader = ui.Gradient.radial(
          pos - Offset(r * 0.15, r * 0.2),
          r * 0.95,
          [cloudColor, cloudColor.withOpacity(0)],
        );
      canvas.drawCircle(pos, r * 0.95, highlightPaint);
    }
  }

  void _paintAtmosphericDust(Canvas canvas, Size size, double windDx) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final d in dust) {
      d.x += windDx * d.speed;
      d.y -= 0.3 + sin(tick + d.x) * 0.2;

      if (d.x > size.width) d.x = 0;
      if (d.x < 0) d.x = size.width;
      if (d.y < 0) d.y = size.height;

      paint.color = Colors.white.withOpacity(d.opacity * 0.6);
      canvas.drawCircle(Offset(d.x, d.y), d.size, paint);
    }
  }

  void _paintRain(Canvas canvas, Size size, double windDx) {
    final paint = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (final drop in rainDrops) {
      drop.y += drop.speed;
      drop.x += windDx * 2.5;

      if (drop.y > size.height + drop.length) {
        drop.y = -drop.length;
        drop.x = Random().nextDouble() * size.width;
      }
      if (drop.x > size.width) drop.x = 0;
      if (drop.x < 0) drop.x = size.width;

      paint.color = const Color(0xFF38BDF8).withOpacity(drop.opacity);
      final dx = windDx * drop.length * 0.4;
      canvas.drawLine(
        Offset(drop.x, drop.y),
        Offset(drop.x + dx, drop.y + drop.length),
        paint,
      );
    }
  }

  void _paintSnow(Canvas canvas, Size size, double windDx) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final flake in snowFlakes) {
      flake.y += flake.speed;
      flake.x += sin(tick * 1.5 + flake.drift) * 0.8 + windDx * 1.0;

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
  bool shouldRepaint(covariant _ARWeatherPainter oldDelegate) => true;
}
