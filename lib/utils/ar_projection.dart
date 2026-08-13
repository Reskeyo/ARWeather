import 'dart:math';
import 'package:flutter/material.dart';

class ARProjectedPoint {
  final double x;
  final double y;
  final double distanceMeters;
  final double bearingDegrees;
  final bool isVisible;
  final double scale;
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

class ARProjection {
  static const double earthRadiusMeters = 6371000.0;
  static const double defaultHorizontalFov = 65.0; // degrees
  static const double defaultVerticalFov = 75.0; // degrees

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

  /// Projects a target GPS point into 2D screen space with smooth horizon sky anchoring.
  static ARProjectedPoint projectToScreen({
    required double userLat,
    required double userLon,
    required double targetLat,
    required double targetLon,
    double targetAltitudeMeters = 1600.0,
    required double deviceHeading,
    required double devicePitch,
    required Size screenSize,
    double maxDistanceMeters = 15000.0,
    double hFov = defaultHorizontalFov,
    double vFov = defaultVerticalFov,
  }) {
    final distance = distanceBetween(userLat, userLon, targetLat, targetLon);
    final bearing = bearingTo(userLat, userLon, targetLat, targetLon);

    // Relative horizontal angle (-180° to +180°)
    double relBearing = (bearing - deviceHeading + 540) % 360 - 180;

    // Horizon Y calculation
    final horizonY = (screenSize.height / 2) + (devicePitch / (vFov / 2)) * (screenSize.height / 2);

    // Cloud elevation above horizon
    final elevationAngle = _toDegrees(atan2(targetAltitudeMeters, max(200.0, distance)));
    final screenX = (screenSize.width / 2) + (relBearing / (hFov / 2)) * (screenSize.width / 2);

    // Position clouds gracefully in the sky band above horizon
    final screenY = horizonY - (elevationAngle / (vFov / 2)) * (screenSize.height * 0.4);

    final isVisible = screenX >= -250 &&
        screenX <= screenSize.width + 250 &&
        screenY >= -300 &&
        screenY <= screenSize.height + 300;

    final distRatio = (distance / maxDistanceMeters).clamp(0.0, 1.0);
    final scale = (1.1 - distRatio * 0.7).clamp(0.3, 1.1);
    final opacity = (1.0 - distRatio * 0.55).clamp(0.3, 0.95);

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
