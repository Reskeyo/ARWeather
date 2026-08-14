import 'dart:async';
import 'package:flutter_compass/flutter_compass.dart';

/// Service for reading rock-solid compass heading data with NaN & anomaly protection.
class CompassService {
  /// Returns a broadcast stream of valid compass headings in degrees (0-360°).
  Stream<double> get headingStream {
    final stream = FlutterCompass.events;
    if (stream == null) return const Stream.empty();

    return stream
        .map((event) {
          // Standard compass heading
          final double? h = event.heading;
          if (h == null || h.isNaN || h.isInfinite) return null;
          return (h % 360.0 + 360.0) % 360.0;
        })
        .where((h) => h != null)
        .cast<double>();
  }
}
