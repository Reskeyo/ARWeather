import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/weather_data.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import '../services/compass_service.dart';

// ─── Service Providers ───────────────────────────────────────────────────────

final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final compassServiceProvider = Provider<CompassService>((ref) {
  return CompassService();
});

// ─── Weather Data Providers ──────────────────────────────────────────────────

final weatherDataProvider = FutureProvider.autoDispose<WeatherData>((ref) async {
  ref.watch(weatherRefreshProvider);

  final locationService = ref.read(locationServiceProvider);
  final weatherService = ref.read(weatherServiceProvider);

  final position = await locationService.getCurrentPosition();

  return weatherService.fetchWeather(
    latitude: position.latitude,
    longitude: position.longitude,
  );
});

final weatherGridProvider = FutureProvider.autoDispose<WeatherGridData>((ref) async {
  ref.watch(weatherRefreshProvider);

  final locationService = ref.read(locationServiceProvider);
  final weatherService = ref.read(weatherServiceProvider);

  final position = await locationService.getCurrentPosition();

  return weatherService.fetchWeatherGrid(
    latitude: position.latitude,
    longitude: position.longitude,
  );
});

final weatherRefreshProvider = StateProvider<int>((ref) => 0);

// ─── Rock-Solid Smooth Compass Heading Provider ─────────────────────────────

/// Streams filtered, jitter-free compass heading (0-360°) with NaN protection.
final compassHeadingProvider = StreamProvider.autoDispose<double>((ref) {
  final compassService = ref.read(compassServiceProvider);
  double currentHeading = 0.0;
  bool initialized = false;

  return compassService.headingStream.map((targetHeading) {
    if (targetHeading.isNaN || targetHeading.isInfinite) {
      return currentHeading;
    }

    if (!initialized) {
      currentHeading = targetHeading;
      initialized = true;
      return targetHeading;
    }

    double diff = targetHeading - currentHeading;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    // Smooth filter (alpha = 0.15)
    currentHeading = (currentHeading + diff * 0.15 + 360.0) % 360.0;
    return currentHeading;
  });
});

// ─── Rock-Solid Smooth Device Pitch Provider ────────────────────────────────

/// Streams smooth, stabilized pitch angle (-60° to +60°) with NaN protection.
final devicePitchProvider = StreamProvider.autoDispose<double>((ref) {
  double currentPitch = 0.0;
  bool initialized = false;

  return accelerometerEventStream().map((event) {
    if (event.x.isNaN || event.y.isNaN || event.z.isNaN) {
      return currentPitch;
    }

    final double denom = sqrt(event.x * event.x + event.y * event.y);
    if (denom == 0 || denom.isNaN) return currentPitch;

    // Pitch: tilting phone back (looking up) is positive, forward (looking down) is negative
    final rawPitchRad = atan2(event.z, denom);
    final rawPitchDeg = (rawPitchRad * 180.0 / pi).clamp(-60.0, 60.0);

    if (rawPitchDeg.isNaN || rawPitchDeg.isInfinite) return currentPitch;

    if (!initialized) {
      currentPitch = rawPitchDeg;
      initialized = true;
      return rawPitchDeg;
    }

    // Low-pass filter (alpha = 0.12)
    currentPitch = currentPitch * 0.88 + rawPitchDeg * 0.12;
    return currentPitch;
  });
});

// ─── Derived State ───────────────────────────────────────────────────────────

final windRelativeAngleProvider = Provider<double>((ref) {
  final heading = ref.watch(compassHeadingProvider).valueOrNull ?? 0.0;
  final weather = ref.watch(weatherDataProvider).valueOrNull;
  if (weather == null) return 0.0;

  final angle = (weather.windDirection - heading + 360.0) % 360.0;
  return angle.isNaN ? 0.0 : angle;
});
