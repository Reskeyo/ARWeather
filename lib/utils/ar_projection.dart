import 'dart:math';
import 'package:flutter/material.dart';

/// Represents a 3D point projected onto the 2D AR screen viewport.
class ARProjectedPoint {
  /// 2D X coordinate on screen in logical pixels.
  final double x;

  /// 2D Y coordinate on screen in logical pixels.
  final double y;

  /// Ground distance in meters to target (0 for ambient sky objects).
  final double distanceMeters;

  /// Compass bearing to target in degrees (0° - 360°).
  final double bearingDegrees;

  /// Elevation angle above horizontal in degrees (-90° to +90°).
  final double elevationDegrees;

  /// Whether the point is within the visible camera viewport frustum.
  final bool isVisible;

  /// Distance / perspective scale factor (e.g. 0.4 to 1.2).
  final double scale;

  /// Atmospheric / distance opacity factor (e.g. 0.3 to 1.0).
  final double opacity;

  const ARProjectedPoint({
    required this.x,
    required this.y,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.elevationDegrees,
    required this.isVisible,
    required this.scale,
    required this.opacity,
  });
}

/// Advanced 3-DOF AR Perspective Projection Engine.
///
/// Converts geographic GPS coordinates and celestial/sky dome angles (Azimuth & Elevation)
/// into 2D camera viewport coordinates with full Pitch and Roll tilt compensation.
class ARProjection {
  static const double earthRadiusMeters = 6371000.0;
  static const double defaultHorizontalFov = 52.0; // Portrait mode typical H-FOV
  static const double defaultVerticalFov = 68.0;   // Portrait mode typical V-FOV

  /// Great-circle distance between two GPS coordinates in meters (Haversine formula).
  static double distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(max(0.0, 1.0 - a)));
    final dist = earthRadiusMeters * c;
    return dist.isNaN ? 1000.0 : dist;
  }

  /// Initial compass bearing in degrees (0° - 360°) from point 1 to point 2.
  static double bearingTo(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final phi1 = _toRadians(lat1);
    final phi2 = _toRadians(lat2);
    final dLambda = _toRadians(lon2 - lon1);

    final y = sin(dLambda) * cos(phi2);
    final x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dLambda);

    final bearingRad = atan2(y, x);
    final deg = (_toDegrees(bearingRad) + 360.0) % 360.0;
    return deg.isNaN ? 0.0 : deg;
  }

  /// Projects an absolute spherical sky coordinate (Azimuth + Elevation) to 2D screen space
  /// with device heading, pitch, and roll compensation.
  static ARProjectedPoint projectSphericalToScreen({
    required double azimuthDegrees,
    required double elevationDegrees,
    required double deviceHeading,
    required double devicePitch,
    required double deviceRoll,
    required Size screenSize,
    double distanceMeters = 5000.0,
    double hFov = defaultHorizontalFov,
    double vFov = defaultVerticalFov,
    double maxDistanceMeters = 15000.0,
  }) {
    if (screenSize.width <= 0 || screenSize.height <= 0) {
      return const ARProjectedPoint(
        x: 0,
        y: 0,
        distanceMeters: 0,
        bearingDegrees: 0,
        elevationDegrees: 0,
        isVisible: false,
        scale: 1.0,
        opacity: 1.0,
      );
    }

    final safeHeading = deviceHeading.isFinite ? (deviceHeading % 360.0 + 360.0) % 360.0 : 0.0;
    final safePitch = devicePitch.isFinite ? devicePitch.clamp(-85.0, 85.0) : 0.0;
    final safeRoll = deviceRoll.isFinite ? deviceRoll.clamp(-90.0, 90.0) : 0.0;

    // Relative horizontal bearing in [-180°, +180°]
    double relBearing = (azimuthDegrees - safeHeading + 540.0) % 360.0 - 180.0;

    // Relative vertical elevation in [-180°, +180°]
    double relElevation = elevationDegrees - safePitch;

    // Behind camera check
    final isBehind = relBearing.abs() > 80.0 || relElevation.abs() > 80.0;

    final halfHFovRad = _toRadians(hFov / 2.0);
    final halfVFovRad = _toRadians(vFov / 2.0);

    // Rectilinear camera projection
    final tanRelH = tan(_toRadians(relBearing));
    final tanRelV = tan(_toRadians(relElevation));

    final unrotX = (screenSize.width / 2.0) + (tanRelH / tan(halfHFovRad)) * (screenSize.width / 2.0);
    final unrotY = (screenSize.height / 2.0) - (tanRelV / tan(halfVFovRad)) * (screenSize.height / 2.0);

    // Apply Roll rotation around viewport center
    final rollRad = _toRadians(-safeRoll);
    final cosRoll = cos(rollRad);
    final sinRoll = sin(rollRad);

    final dx = unrotX - (screenSize.width / 2.0);
    final dy = unrotY - (screenSize.height / 2.0);

    final screenX = (screenSize.width / 2.0) + (dx * cosRoll - dy * sinRoll);
    final screenY = (screenSize.height / 2.0) + (dx * sinRoll + dy * cosRoll);

    final isVisible = !isBehind &&
        screenX.isFinite &&
        screenY.isFinite &&
        screenX >= -250 &&
        screenX <= screenSize.width + 250 &&
        screenY >= -300 &&
        screenY <= screenSize.height + 300;

    final distRatio = (distanceMeters / maxDistanceMeters).clamp(0.0, 1.0);
    final scale = (1.2 - distRatio * 0.6).clamp(0.4, 1.25);
    final opacity = (1.0 - distRatio * 0.45).clamp(0.45, 0.98);

    return ARProjectedPoint(
      x: screenX.isFinite ? screenX : 0.0,
      y: screenY.isFinite ? screenY : 0.0,
      distanceMeters: distanceMeters,
      bearingDegrees: azimuthDegrees,
      elevationDegrees: elevationDegrees,
      isVisible: isVisible,
      scale: scale,
      opacity: opacity,
    );
  }

  /// Projects a target GPS point with a physical altitude into 2D AR screen coordinates.
  static ARProjectedPoint projectToScreen({
    required double userLat,
    required double userLon,
    required double targetLat,
    required double targetLon,
    double targetAltitudeMeters = 1500.0,
    required double deviceHeading,
    required double devicePitch,
    double deviceRoll = 0.0,
    required Size screenSize,
    double maxDistanceMeters = 15000.0,
    double hFov = defaultHorizontalFov,
    double vFov = defaultVerticalFov,
  }) {
    final distance = distanceBetween(userLat, userLon, targetLat, targetLon);
    final bearing = bearingTo(userLat, userLon, targetLat, targetLon);

    // Compute elevation angle above horizon in degrees
    final effectiveDistance = max(150.0, distance);
    final elevationAngle = _toDegrees(atan2(targetAltitudeMeters, effectiveDistance));

    return projectSphericalToScreen(
      azimuthDegrees: bearing,
      elevationDegrees: elevationAngle,
      deviceHeading: deviceHeading,
      devicePitch: devicePitch,
      deviceRoll: deviceRoll,
      screenSize: screenSize,
      distanceMeters: distance,
      hFov: hFov,
      vFov: vFov,
      maxDistanceMeters: maxDistanceMeters,
    );
  }

  static double _toRadians(double deg) => deg * pi / 180.0;
  static double _toDegrees(double rad) => rad * 180.0 / pi;
}

