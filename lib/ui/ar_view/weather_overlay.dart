import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/weather_data.dart';
import '../../utils/ar_projection.dart';

/// Representation of a procedural volumetric cloud cluster in the 360° sky dome.
class _SkyDomeCloud {
  double azimuth;
  double elevation;
  final double baseRadius;
  final double opacity;
  final List<Offset> puffOffsets;
  final List<double> puffRadii;

  _SkyDomeCloud({
    required this.azimuth,
    required this.elevation,
    required this.baseRadius,
    required this.opacity,
    required this.puffOffsets,
    required this.puffRadii,
  });
}

class _WindParticle {
  double x;
  double y;
  double length;
  double speed;
  double opacity;

  _WindParticle({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
    required this.opacity,
  });
}

class _PrecipitationParticle {
  double x;
  double y;
  double size;
  double speed;
  double drift;
  double opacity;

  _PrecipitationParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.drift,
    required this.opacity,
  });
}

/// Advanced True AR Weather Overlay rendering:
/// 1. Roll & Pitch compensated Horizon Line & Aviation Compass HUD
/// 2. Continuous 360° Volumetric Sky Dome Cloud Layer
/// 3. 3D Spatial Radar Waypoints & Rain Shafts
/// 4. Dynamic 3D Wind Streamlines & Precipitation (Rain / Snow / Lightning)
class WeatherOverlay extends StatefulWidget {
  final double userLat;
  final double userLon;
  final List<WeatherGridPoint> gridPoints;
  final double heading;
  final double pitch;
  final double roll;
  final WeatherData centerWeather;

  const WeatherOverlay({
    super.key,
    required this.userLat,
    required this.userLon,
    required this.gridPoints,
    required this.heading,
    required this.pitch,
    this.roll = 0.0,
    required this.centerWeather,
  });

  @override
  State<WeatherOverlay> createState() => _WeatherOverlayState();
}

class _WeatherOverlayState extends State<WeatherOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_SkyDomeCloud> _skyClouds = [];
  final List<_WindParticle> _windParticles = [];
  final List<_PrecipitationParticle> _precipParticles = [];
  final Random _random = Random();
  bool _initialized = false;
  double _lastTick = 0.0;
  double _lightningAlpha = 0.0;
  double _nextLightningTime = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _initSkyDomeClouds();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initSkyDomeClouds() {
    _skyClouds.clear();
    // 24 volumetric cloud anchors distributed across 360° azimuth and multiple elevation tiers
    const azimuthSteps = [
      0.0, 20.0, 45.0, 70.0, 90.0, 115.0, 140.0, 160.0,
      180.0, 205.0, 230.0, 250.0, 270.0, 295.0, 320.0, 345.0,
      15.0, 75.0, 135.0, 195.0, 255.0, 315.0, 50.0, 230.0,
    ];

    const elevationTiers = [
      22.0, 38.0, 28.0, 48.0, 25.0, 42.0, 30.0, 52.0,
      20.0, 36.0, 26.0, 45.0, 24.0, 40.0, 32.0, 50.0,
      58.0, 62.0, 55.0, 65.0, 58.0, 64.0, 35.0, 44.0,
    ];

    for (int i = 0; i < azimuthSteps.length; i++) {
      final baseR = 45.0 + _random.nextDouble() * 35.0;
      final puffOffsets = <Offset>[
        Offset.zero,
        Offset(-baseR * 0.55, baseR * 0.05),
        Offset(baseR * 0.55, -baseR * 0.1),
        Offset(-baseR * 0.95, baseR * 0.15),
        Offset(baseR * 0.95, baseR * 0.18),
        Offset(0, -baseR * 0.28),
      ];

      final puffRadii = <double>[
        baseR * 0.95,
        baseR * 0.75,
        baseR * 0.80,
        baseR * 0.55,
        baseR * 0.60,
        baseR * 0.70,
      ];

      _skyClouds.add(_SkyDomeCloud(
        azimuth: azimuthSteps[i] + (_random.nextDouble() * 10 - 5),
        elevation: elevationTiers[i],
        baseRadius: baseR,
        opacity: 0.85 + _random.nextDouble() * 0.15,
        puffOffsets: puffOffsets,
        puffRadii: puffRadii,
      ));
    }
  }

  void _initParticles(Size size) {
    if (_initialized || size.width <= 0) return;
    _initialized = true;

    _windParticles.clear();
    for (int i = 0; i < 40; i++) {
      _windParticles.add(_WindParticle(
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height * 0.8,
        length: 50 + _random.nextDouble() * 80,
        speed: 2.5 + _random.nextDouble() * 4.0,
        opacity: 0.4 + _random.nextDouble() * 0.5,
      ));
    }

    _precipParticles.clear();
    for (int i = 0; i < 70; i++) {
      _precipParticles.add(_PrecipitationParticle(
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height,
        size: 2.0 + _random.nextDouble() * 4.0,
        speed: 3.0 + _random.nextDouble() * 5.0,
        drift: _random.nextDouble() * pi * 2,
        opacity: 0.5 + _random.nextDouble() * 0.45,
      ));
    }
  }

  void _updateSimulation(double currentTick) {
    if (_lastTick == 0.0) {
      _lastTick = currentTick;
      return;
    }
    final dt = (currentTick - _lastTick).clamp(0.001, 0.1);
    _lastTick = currentTick;

    // Wind drift for sky dome clouds
    final windDir = widget.centerWeather.windDirection;
    final windSpeed = widget.centerWeather.windSpeed;
    final windRad = windDir * pi / 180.0;

    final dAzimuth = sin(windRad) * windSpeed * 0.05 * dt;
    final dElevation = -cos(windRad) * windSpeed * 0.02 * dt;

    for (final cloud in _skyClouds) {
      cloud.azimuth = (cloud.azimuth + dAzimuth + 360.0) % 360.0;
      cloud.elevation = (cloud.elevation + dElevation).clamp(12.0, 78.0);
    }

    // Thunderstorm lightning logic
    final isStorm = widget.centerWeather.weatherCode >= 95 || widget.centerWeather.weatherCode == 63;
    if (isStorm) {
      if (currentTick > _nextLightningTime) {
        _lightningAlpha = 0.85;
        _nextLightningTime = currentTick + 3.0 + _random.nextDouble() * 6.0;
      } else if (_lightningAlpha > 0.0) {
        _lightningAlpha = (_lightningAlpha - dt * 3.5).clamp(0.0, 1.0);
      }
    } else {
      _lightningAlpha = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final currentTick = DateTime.now().millisecondsSinceEpoch / 1000.0;
        _updateSimulation(currentTick);

        return CustomPaint(
          size: Size.infinite,
          painter: _ARSpatialWeatherPainter(
            userLat: widget.userLat,
            userLon: widget.userLon,
            gridPoints: widget.gridPoints,
            heading: widget.heading,
            pitch: widget.pitch,
            roll: widget.roll,
            centerWeather: widget.centerWeather,
            skyClouds: _skyClouds,
            windParticles: _windParticles,
            precipParticles: _precipParticles,
            lightningAlpha: _lightningAlpha,
            tick: currentTick,
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
  final double roll;
  final WeatherData centerWeather;
  final List<_SkyDomeCloud> skyClouds;
  final List<_WindParticle> windParticles;
  final List<_PrecipitationParticle> precipParticles;
  final double lightningAlpha;
  final double tick;
  final void Function(Size) onInit;

  _ARSpatialWeatherPainter({
    required this.userLat,
    required this.userLon,
    required this.gridPoints,
    required this.heading,
    required this.pitch,
    required this.roll,
    required this.centerWeather,
    required this.skyClouds,
    required this.windParticles,
    required this.precipParticles,
    required this.lightningAlpha,
    required this.tick,
    required this.onInit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    onInit(size);
    if (size.width <= 0 || size.height <= 0) return;

    final safePitch = pitch.isFinite ? pitch.clamp(-85.0, 85.0) : 0.0;
    final safeHeading = heading.isFinite ? (heading % 360.0 + 360.0) % 360.0 : 0.0;
    final safeRoll = roll.isFinite ? roll.clamp(-90.0, 90.0) : 0.0;

    // ── 1. Lightning Ambient Flash (Thunderstorm mode) ──
    if (lightningAlpha > 0.01) {
      final flashPaint = Paint()..color = Colors.white.withOpacity(lightningAlpha * 0.55);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), flashPaint);
    }

    // ── 2. Draw 360° Volumetric Sky Dome Cloud Layer ──
    _drawSkyDomeClouds(canvas, size, safeHeading, safePitch, safeRoll);

    // ── 3. Draw Roll-Compensated AR Horizon HUD & Aviation Compass Scale ──
    _drawRollCompensatedHorizonHUD(canvas, size, safeHeading, safePitch, safeRoll);

    // ── 4. Draw 3D Spatial Radar Weather Waypoints & Local Rain Shafts ──
    _drawSpatialWeatherRadarWaypoints(canvas, size, safeHeading, safePitch, safeRoll);

    // ── 5. Draw 3D Wind Direction Streamlines & Vector Pointer ──
    _draw3DWindStreams(canvas, size, safeHeading, safePitch, safeRoll);

    // ── 6. Draw Precipitation (Rain / Snow) ──
    _drawPrecipitation(canvas, size);
  }

  /// Draws a continuous 360° procedural volumetric cloud sky layer that matches cloudCover %.
  void _drawSkyDomeClouds(
    Canvas canvas,
    Size size,
    double safeHeading,
    double safePitch,
    double safeRoll,
  ) {
    final cover = centerWeather.cloudCover.clamp(0.0, 100.0);
    if (cover <= 2.0) return; // Completely clear sky

    // Determine number of clouds to render based on cloud cover
    final visibleCount = ((cover / 100.0) * skyClouds.length).ceil().clamp(1, skyClouds.length);
    final isStorm = centerWeather.weatherCode >= 60 || centerWeather.weatherCode >= 95;

    for (int i = 0; i < visibleCount; i++) {
      final cloud = skyClouds[i];

      final proj = ARProjection.projectSphericalToScreen(
        azimuthDegrees: cloud.azimuth,
        elevationDegrees: cloud.elevation,
        deviceHeading: safeHeading,
        devicePitch: safePitch,
        deviceRoll: safeRoll,
        screenSize: size,
        distanceMeters: 4000.0,
      );

      if (!proj.isVisible) continue;

      final center = Offset(proj.x, proj.y);
      final r = cloud.baseRadius * proj.scale;
      final opacity = (cloud.opacity * (cover / 100.0).clamp(0.55, 1.0)).clamp(0.45, 0.95);

      _drawSingleVolumetricCloud(
        canvas: canvas,
        center: center,
        baseRadius: r,
        opacity: opacity,
        isStorm: isStorm,
        offsets: cloud.puffOffsets,
        radii: cloud.puffRadii,
        scale: proj.scale,
      );
    }
  }

  void _drawSingleVolumetricCloud({
    required Canvas canvas,
    required Offset center,
    required double baseRadius,
    required double opacity,
    required bool isStorm,
    required List<Offset> offsets,
    required List<double> radii,
    required double scale,
  }) {
    final coreColor = isStorm
        ? const Color(0xFF334155).withOpacity(opacity * 0.92)
        : const Color(0xFFF8FAFC).withOpacity(opacity * 0.95);

    final highlightColor = isStorm
        ? const Color(0xFF64748B).withOpacity(opacity * 0.85)
        : Colors.white.withOpacity(opacity);

    final shadowColor = isStorm
        ? const Color(0xFF0F172A).withOpacity(opacity * 0.85)
        : const Color(0xFF64748B).withOpacity(opacity * 0.45);

    final rimGlowColor = isStorm
        ? const Color(0xFF818CF8).withOpacity(opacity * 0.35)
        : const Color(0xFF38BDF8).withOpacity(opacity * 0.35);

    // Pass 1: Volumetric base shadows
    for (int i = 0; i < offsets.length; i++) {
      final p = center + offsets[i] * scale;
      final puffR = radii[i] * scale;

      final shadowPaint = Paint()
        ..shader = ui.Gradient.radial(
          p + Offset(0, puffR * 0.3),
          puffR * 1.25,
          [shadowColor, shadowColor.withOpacity(0.0)],
        );
      canvas.drawCircle(p + Offset(0, puffR * 0.3), puffR * 1.25, shadowPaint);
    }

    // Pass 2: Volumetric cloud core body
    for (int i = 0; i < offsets.length; i++) {
      final p = center + offsets[i] * scale;
      final puffR = radii[i] * scale;

      final corePaint = Paint()
        ..shader = ui.Gradient.radial(
          p - Offset(puffR * 0.15, puffR * 0.15),
          puffR,
          [coreColor, coreColor.withOpacity(0.1)],
        );
      canvas.drawCircle(p, puffR, corePaint);
    }

    // Pass 3: Sun-facing top highlight & soft glowing rim
    for (int i = 0; i < offsets.length; i++) {
      final p = center + offsets[i] * scale;
      final puffR = radii[i] * scale * 0.75;

      final highlightPaint = Paint()
        ..shader = ui.Gradient.radial(
          p - Offset(puffR * 0.25, puffR * 0.35),
          puffR,
          [highlightColor, highlightColor.withOpacity(0.0)],
        );
      canvas.drawCircle(p - Offset(0, puffR * 0.1), puffR, highlightPaint);
    }

    // Subtle edge rim for crisp AR definition
    final borderPaint = Paint()
      ..color = rimGlowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, baseRadius * 0.9, borderPaint);
  }

  /// Draws a roll & pitch compensated Horizon HUD with degree ladders and cardinal markers.
  void _drawRollCompensatedHorizonHUD(
    Canvas canvas,
    Size size,
    double safeHeading,
    double safePitch,
    double safeRoll,
  ) {
    final center = Offset(size.width / 2.0, size.height / 2.0);
    final rollRad = safeRoll * pi / 180.0;

    // Pitch displacement along unrotated vertical axis
    final halfVFovRad = 68.0 / 2.0 * pi / 180.0;
    final tanPitch = tan(safePitch * pi / 180.0);
    final unrotHorizonY = (size.height / 2.0) + (tanPitch / tan(halfVFovRad)) * (size.height / 2.0);

    canvas.save();
    // Rotate canvas around screen center by -roll to keep horizon locked to real world
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-rollRad);
    canvas.translate(-center.dx, -center.dy);

    // ── Glowing Horizon Line ──
    final horizonPaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.65)
      ..strokeWidth = 2.0;

    final horizonGlow = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.35)
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final lineStart = Offset(-size.width * 0.6, unrotHorizonY);
    final lineEnd = Offset(size.width * 1.6, unrotHorizonY);

    canvas.drawLine(lineStart, lineEnd, horizonGlow);
    canvas.drawLine(lineStart, lineEnd, horizonPaint);

    // ── Center Horizon Level Indicator ──
    _drawHorizonCenterBadge(canvas, size, unrotHorizonY, safePitch);

    // ── Pitch Degree Ladder Marks (+10°, +20°, +30°, -10°, -20°, -30°) ──
    _drawPitchLadder(canvas, size, unrotHorizonY, safePitch, halfVFovRad);

    // ── Cardinal & Intercardinal Compass Markers along Horizon (N, NE, E, SE, S, SW, W, NW) ──
    _drawCompassMarkersAlongHorizon(canvas, size, unrotHorizonY, safeHeading);

    canvas.restore();
  }

  void _drawHorizonCenterBadge(Canvas canvas, Size size, double horizonY, double pitchDeg) {
    final cx = size.width / 2.0;
    final text = '${pitchDeg.round() >= 0 ? '+' : ''}${pitchDeg.round()}° HORIZON';

    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Color(0xFF38BDF8),
        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
      ),
    );

    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, horizonY + 14), width: tp.width + 12, height: tp.height + 4),
      const Radius.circular(6),
    );

    final bgPaint = Paint()..color = const Color(0xFF0F172A).withOpacity(0.85);
    final borderPaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(badgeRect, bgPaint);
    canvas.drawRRect(badgeRect, borderPaint);
    tp.paint(canvas, Offset(cx - tp.width / 2.0, horizonY + 14 - tp.height / 2.0));
  }

  void _drawPitchLadder(
    Canvas canvas,
    Size size,
    double horizonY,
    double pitchDeg,
    double halfVFovRad,
  ) {
    final ladderPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1.5;

    const pitchAngles = [10.0, 20.0, 30.0, -10.0, -20.0, -30.0];
    final cx = size.width / 2.0;

    for (final angle in pitchAngles) {
      final relAngle = angle - pitchDeg;
      if (relAngle.abs() > 30.0) continue;

      final tanRel = tan(relAngle * pi / 180.0);
      final y = (size.height / 2.0) - (tanRel / tan(halfVFovRad)) * (size.height / 2.0);

      final w = angle.abs() % 20 == 0 ? 32.0 : 20.0;
      canvas.drawLine(Offset(cx - w - 24, y), Offset(cx - 24, y), ladderPaint);
      canvas.drawLine(Offset(cx + 24, y), Offset(cx + w + 24, y), ladderPaint);

      final textSpan = TextSpan(
        text: '${angle.round()}°',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.55),
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(cx - w - 28 - tp.width, y - tp.height / 2.0));
      tp.paint(canvas, Offset(cx + w + 28, y - tp.height / 2.0));
    }
  }

  void _drawCompassMarkersAlongHorizon(
    Canvas canvas,
    Size size,
    double horizonY,
    double currentHeading,
  ) {
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

    const hFov = 52.0;
    final halfHFovRad = (hFov / 2.0) * pi / 180.0;

    for (final card in cardinals) {
      final deg = card['deg'] as double;
      final label = card['label'] as String;
      final isPrimary = card['primary'] as bool;

      double relAngle = (deg - currentHeading + 540.0) % 360.0 - 180.0;
      if (relAngle < -hFov / 2 - 12 || relAngle > hFov / 2 + 12) continue;

      final tanRel = tan(relAngle * pi / 180.0);
      final x = (size.width / 2.0) + (tanRel / tan(halfHFovRad)) * (size.width / 2.0);
      if (!x.isFinite) continue;

      final tickHeight = isPrimary ? 16.0 : 9.0;
      final tickPaint = Paint()
        ..color = isPrimary ? const Color(0xFF38BDF8) : Colors.white.withOpacity(0.6)
        ..strokeWidth = isPrimary ? 2.5 : 1.2;

      canvas.drawLine(
        Offset(x, horizonY - tickHeight),
        Offset(x, horizonY),
        tickPaint,
      );

      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: isPrimary ? 14 : 11,
          fontWeight: isPrimary ? FontWeight.w900 : FontWeight.w600,
          color: isPrimary ? const Color(0xFF38BDF8) : Colors.white.withOpacity(0.85),
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      );

      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(
        canvas,
        Offset(x - tp.width / 2.0, horizonY - tickHeight - tp.height - 3),
      );
    }
  }

  /// Draws floating 3D spatial AR radar waypoints for surrounding regional coordinates.
  void _drawSpatialWeatherRadarWaypoints(
    Canvas canvas,
    Size size,
    double safeHeading,
    double safePitch,
    double safeRoll,
  ) {
    for (final point in gridPoints) {
      final proj = ARProjection.projectToScreen(
        userLat: userLat,
        userLon: userLon,
        targetLat: point.latitude,
        targetLon: point.longitude,
        targetAltitudeMeters: 1200.0,
        deviceHeading: safeHeading,
        devicePitch: safePitch,
        deviceRoll: safeRoll,
        screenSize: size,
      );

      if (!proj.isVisible) continue;

      final pos = Offset(proj.x, proj.y);
      final weather = point.weather;

      // Draw Rain Shaft if raining at that regional waypoint
      if (weather.rain > 0.1 || weather.weatherCode >= 50) {
        final shaftPaint = Paint()
          ..shader = ui.Gradient.linear(
            pos,
            pos + Offset(0, 140.0 * proj.scale),
            [
              const Color(0xFF38BDF8).withOpacity(0.45),
              const Color(0xFF0284C7).withOpacity(0.0),
            ],
          );
        canvas.drawRect(
          Rect.fromLTWH(pos.dx - 45.0 * proj.scale, pos.dy, 90.0 * proj.scale, 140.0 * proj.scale),
          shaftPaint,
        );
      }

      // Draw 3D Floating Glass Badge
      _drawRadarWaypointBadge(canvas, pos, proj.distanceMeters, weather, proj.scale);
    }
  }

  void _drawRadarWaypointBadge(
    Canvas canvas,
    Offset position,
    double distanceMeters,
    WeatherData weather,
    double scale,
  ) {
    final km = (distanceMeters / 1000.0).toStringAsFixed(1);
    final text = '${weather.conditionIcon} $km km • ${weather.temperature.round()}°C';

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: (11.0 * scale).clamp(9.0, 13.0),
        fontWeight: FontWeight.bold,
        color: Colors.white,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
      ),
    );

    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    final badgeWidth = tp.width + 16.0;
    final badgeHeight = tp.height + 8.0;

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: position, width: badgeWidth, height: badgeHeight),
      const Radius.circular(10),
    );

    final bgPaint = Paint()..color = const Color(0xFF0F172A).withOpacity(0.82);
    final borderPaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRRect(bgRect, bgPaint);
    canvas.drawRRect(bgRect, borderPaint);

    tp.paint(
      canvas,
      Offset(position.dx - tp.width / 2.0, position.dy - tp.height / 2.0),
    );

    // Anchor pin line dropping to ground
    final pinPaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.4)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      position + Offset(0, badgeHeight / 2.0),
      position + Offset(0, badgeHeight / 2.0 + 16.0),
      pinPaint,
    );
    canvas.drawCircle(position + Offset(0, badgeHeight / 2.0 + 16.0), 2.5, Paint()..color = const Color(0xFF38BDF8));
  }

  /// Draws 3D wind streamline ribbons oriented along the actual wind heading.
  void _draw3DWindStreams(
    Canvas canvas,
    Size size,
    double safeHeading,
    double safePitch,
    double safeRoll,
  ) {
    final windDirection = centerWeather.windDirection;
    final relativeWindAngle = (windDirection - safeHeading + 360.0) % 360.0;
    final windRad = relativeWindAngle * pi / 180.0;
    final windDx = sin(windRad);
    final windDy = -cos(windRad) * 0.35;

    final streamPaint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final effectiveSpeed = max(12.0, centerWeather.windSpeed);

    for (final particle in windParticles) {
      particle.x += windDx * particle.speed * (effectiveSpeed / 16.0).clamp(1.0, 3.5);
      particle.y += windDy * particle.speed * 0.6;

      if (particle.x > size.width + 160) particle.x = -160;
      if (particle.x < -160) particle.x = size.width + 160;
      if (particle.y > size.height) particle.y = 0;
      if (particle.y < 0) particle.y = size.height * 0.8;

      final start = Offset(particle.x, particle.y);
      final end = Offset(
        particle.x + windDx * particle.length,
        particle.y + windDy * particle.length,
      );

      if (!start.dx.isFinite || !end.dx.isFinite) continue;

      final gradient = ui.Gradient.linear(
        start,
        end,
        [
          const Color(0xFF818CF8).withOpacity(0.0),
          const Color(0xFF38BDF8).withOpacity(particle.opacity * 0.8),
          const Color(0xFF818CF8).withOpacity(0.0),
        ],
      );

      streamPaint.shader = gradient;
      canvas.drawLine(start, end, streamPaint);
    }
  }

  /// Draws precipitation (Rain streaks or Snowflakes) based on current weather.
  void _drawPrecipitation(Canvas canvas, Size size) {
    final isSnow = centerWeather.weatherCode >= 70 && centerWeather.weatherCode <= 79;
    final isRain = centerWeather.rain > 0.05 || (centerWeather.weatherCode >= 50 && !isSnow);

    if (!isSnow && !isRain) return;

    if (isSnow) {
      final flakePaint = Paint()..style = PaintingStyle.fill;
      for (final p in precipParticles) {
        p.y += p.speed * 0.8;
        p.x += sin(tick * 2.0 + p.drift) * 1.2;

        if (p.y > size.height) {
          p.y = 0;
          p.x = Random().nextDouble() * size.width;
        }

        flakePaint.color = Colors.white.withOpacity(p.opacity);
        canvas.drawCircle(Offset(p.x, p.y), p.size, flakePaint);
      }
    } else if (isRain) {
      final rainPaint = Paint()
        ..color = const Color(0xFF38BDF8).withOpacity(0.65)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      for (final p in precipParticles) {
        p.y += p.speed * 2.8;
        p.x += 0.8;

        if (p.y > size.height) {
          p.y = 0;
          p.x = Random().nextDouble() * size.width;
        }

        canvas.drawLine(
          Offset(p.x, p.y),
          Offset(p.x + 1.2, p.y + p.size * 5.0),
          rainPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ARSpatialWeatherPainter oldDelegate) => true;
}

