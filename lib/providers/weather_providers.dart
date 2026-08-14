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

/// Streams filtered, jitter-free compass heading (0-360°).
final compassHeadingProvider = StreamProvider.autoDispose<double>((ref) {
  final compassService = ref.read(compassServiceProvider);
  double? currentHeading;

  return compassService.headingStream.map((targetHeading) {
    if (currentHeading == null) {
      currentHeading = targetHeading;
      return targetHeading;
    }

    double diff = targetHeading - currentHeading!;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    // Ignore tiny micro-jitter (< 0.25°)
    if (diff.abs() < 0.25) {
      return currentHeading!;
    }

    // Smooth filter (alpha = 0.10)
    currentHeading = (currentHeading! + diff * 0.10 + 360) % 360;
    return currentHeading!;
  });
});

// ─── Rock-Solid Smooth Device Pitch Provider ────────────────────────────────

/// Streams smooth, stabilized pitch angle (-90° to +90°) for stable AR horizon anchoring.
final devicePitchProvider = StreamProvider.autoDispose<double>((ref) {
  double? currentPitch;

  return accelerometerEventStream().map((event) {
    // When held vertically: Y is gravity down, Z is out of screen
    final rawPitchRad = atan2(event.z, sqrt(event.x * event.x + event.y * event.y));
    final rawPitchDeg = (rawPitchRad * 180 / pi).clamp(-85.0, 85.0);

    if (currentPitch == null) {
      currentPitch = rawPitchDeg;
      return rawPitchDeg;
    }

    final diff = rawPitchDeg - currentPitch!;

    // Ignore tiny micro-accelerometer tremors (< 0.2°)
    if (diff.abs() < 0.2) {
      return currentPitch!;
    }

    // Heavy low-pass filter (alpha = 0.08) for cinematic, jitter-free horizon
    currentPitch = currentPitch! * 0.92 + rawPitchDeg * 0.08;
    return currentPitch!;
  });
});

// ─── Derived State ───────────────────────────────────────────────────────────

final windRelativeAngleProvider = Provider<double>((ref) {
  final heading = ref.watch(compassHeadingProvider).valueOrNull ?? 0.0;
  final weather = ref.watch(weatherDataProvider).valueOrNull;
  if (weather == null) return 0.0;

  return (weather.windDirection - heading + 360) % 360;
});
