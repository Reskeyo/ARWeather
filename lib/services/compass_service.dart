import 'dart:async';
import 'package:flutter_compass/flutter_compass.dart';

/// Service for reading compass heading data calibrated for AR camera mode.
class CompassService {
  /// Returns a broadcast stream of compass headings in degrees (0-360°).
  Stream<double> get headingStream {
    final stream = FlutterCompass.events;
    if (stream == null) return const Stream.empty();

    return stream.map((event) {
      // Prefer headingForCameraMode when available (calibrated for upright AR viewing)
      final raw = event.headingForCameraMode ?? event.heading ?? 0.0;
      return (raw % 360 + 360) % 360;
    });
  }
}
