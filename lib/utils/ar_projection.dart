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
    final dist = earthRadiusMeters * c;
    return dist.isNaN ? 1000.0 : dist;
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
    final deg = (_toDegrees(bearingRad) + 360.0) % 360.0;
    return deg.isNaN ? 0.0 : deg;
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
    if (screenSize.width <= 0 || screenSize.height <= 0) {
      return const ARProjectedPoint(
        x: 0,
        y: 0,
        distanceMeters: 0,
        bearingDegrees: 0,
        isVisible: false,
        scale: 1,
        opacity: 1,
      );
    }

    final safeHeading = deviceHeading.isNaN ? 0.0 : deviceHeading;
    final safePitch = devicePitch.isNaN ? 0.0 : devicePitch.clamp(-60.0, 60.0);

    final distance = distanceBetween(userLat, userLon, targetLat, targetLon);
    final bearing = bearingTo(userLat, userLon, targetLat, targetLon);

    // Relative horizontal angle (-180° to +180°)
    double relBearing = (bearing - safeHeading + 540.0) % 360.0 - 180.0;

    // Horizon Y calculation
    final horizonY = (screenSize.height / 2) + (safePitch / (vFov / 2)) * (screenSize.height / 2);

    // Cloud elevation above horizon
    final elevationAngle = _toDegrees(atan2(targetAltitudeMeters, max(200.0, distance)));
    final screenX = (screenSize.width / 2) + (relBearing / (hFov / 2)) * (screenSize.width / 2);

    // Position clouds gracefully in the sky band above horizon
    final screenY = horizonY - (elevationAngle / (vFov / 2)) * (screenSize.height * 0.45);

    final isVisible = screenX.isFinite &&
        screenY.isFinite &&
        screenX >= -300 &&
        screenX <= screenSize.width + 300 &&
        screenY >= -350 &&
        screenY <= screenSize.height + 350;

    final distRatio = (distance / maxDistanceMeters).clamp(0.0, 1.0);
    final scale = (1.1 - distRatio * 0.65).clamp(0.35, 1.1);
    final opacity = (1.0 - distRatio * 0.5).clamp(0.4, 0.95);

    return ARProjectedPoint(
      x: screenX.isFinite ? screenX : 0.0,
      y: screenY.isFinite ? screenY : 0.0,
      distanceMeters: distance,
      bearingDegrees: bearing,
      isVisible: isVisible,
      scale: scale,
      opacity: opacity,
    );
  }

  static double _toRadians(double deg) => deg * pi / 180.0;
  static double _toDegrees(double rad) => rad * 180.0 / pi;
}
