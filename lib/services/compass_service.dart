import 'dart:async';
import 'package:flutter_compass/flutter_compass.dart';

/// Service for reading compass heading data.
///
/// Streams the device's heading in degrees (0-360°, magnetic north).
class CompassService {
  StreamSubscription<CompassEvent>? _subscription;

  /// Returns a broadcast stream of compass headings in degrees.
  ///
  /// Each event is the heading in degrees from magnetic north.
  Stream<double> get headingStream {
    return FlutterCompass.events?.map((event) => event.heading ?? 0.0) ??
        const Stream.empty();
  }

  /// Cleans up the compass subscription.
  void dispose() {
    _subscription?.cancel();
  }
}
