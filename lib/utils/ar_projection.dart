import 'dart:math';
import 'package:flutter/material.dart';

/// Representation of a projected AR 3D point mapped to 2D screen coordinates.
class ARProjectedPoint {
  /// Screen X coordinate in logical pixels.
  final double x;

  /// Screen Y coordinate in logical pixels.
  final double y;

  /// Distance from user in meters.
  final double distanceMeters;

  /// Compass bearing from user to target (0 - 360°).
  final double bearingDegrees;

  /// Whether the point is currently within the camera screen bounds.
  final bool isVisible;

  /// Scale factor based on distance (1.0 = close, 0.2 = far).
  final double scale;

  /// Opacity factor based on distance & fog.
  final double opacity;

  const ARProjectedPoint({
    required this.x,
    required this.y,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.isVisible,
    required this.scale,
    required this.opacity,
  });
}

/// Utility for calculating geographical distances, bearings, and 3D-to-2D AR projections.
class ARProjection {
  static const double earthRadiusMeters = 6371000.0;
  static const double defaultHorizontalFov = 65.0; // degrees
  static const double defaultVerticalFov = 85.0; // degrees

  /// Calculates Haversine distance in meters between two lat/lon points.
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

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Calculates initial compass bearing in degrees (0-360) from point 1 to point 2.
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
    return (_toDegrees(bearingRad) + 360) % 360;
  }

  /// Projects a target GPS coordinate + altitude onto the 2D screen coordinate space
  /// given the device heading (azimuth) and pitch (tilt).
  static ARProjectedPoint projectToScreen({
    required double userLat,
    required double userLon,
    required double targetLat,
    required double targetLon,
    double targetAltitudeMeters = 1200.0, // Average cloud base height
    required double deviceHeading, // 0-360° (0=N, 90=E)
    required double devicePitch, // -90 to +90° (0=horizontal, +45=looking up at sky)
    required Size screenSize,
    double maxDistanceMeters = 15000.0, // 15 km radar range
    double hFov = defaultHorizontalFov,
    double vFov = defaultVerticalFov,
  }) {
    final distance = distanceBetween(userLat, userLon, targetLat, targetLon);
    final bearing = bearingTo(userLat, userLon, targetLat, targetLon);

    // Relative horizontal angle (-180° to +180°)
    double relBearing = (bearing - deviceHeading + 540) % 360 - 180;

    // Elevation angle of cloud in the sky (degrees)
    final elevationAngle =
        _toDegrees(atan2(targetAltitudeMeters, max(100.0, distance)));

    // Relative vertical pitch angle (-90° to +90°)
    final relPitch = elevationAngle - devicePitch;

    // Map angles to screen X and Y coordinates
    final screenX =
        (screenSize.width / 2) + (relBearing / (hFov / 2)) * (screenSize.width / 2);
    final screenY =
        (screenSize.height / 2) - (relPitch / (vFov / 2)) * (screenSize.height / 2);

    // Check if within visible screen bounds (with margin)
    final isVisible = screenX >= -200 &&
        screenX <= screenSize.width + 200 &&
        screenY >= -200 &&
        screenY <= screenSize.height + 200;

    // Distance scale (nearer = larger, further = smaller)
    final distRatio = (distance / maxDistanceMeters).clamp(0.0, 1.0);
    final scale = (1.2 - distRatio * 0.85).clamp(0.25, 1.2);
    final opacity = (1.0 - distRatio * 0.65).clamp(0.25, 0.95);

    return ARProjectedPoint(
      x: screenX,
      y: screenY,
      distanceMeters: distance,
      bearingDegrees: bearing,
      isVisible: isVisible,
      scale: scale,
      opacity: opacity,
    );
  }

  static double _toRadians(double deg) => deg * pi / 180;
  static double _toDegrees(double rad) => rad * 180 / pi;
}
