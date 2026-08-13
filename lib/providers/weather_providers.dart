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

// ─── Smooth Compass Heading Provider (Low-Pass Filter) ──────────────────────

/// Streams smoothed compass heading (0-360°) with Low-Pass filtering to eliminate jitter.
final compassHeadingProvider = StreamProvider.autoDispose<double>((ref) {
  final compassService = ref.read(compassServiceProvider);
  double? lastHeading;

  return compassService.headingStream.map((heading) {
    if (lastHeading == null) {
      lastHeading = heading;
      return heading;
    }

    // Handle 0/360 degree wrap-around smoothing
    double diff = heading - lastHeading!;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    lastHeading = (lastHeading! + diff * 0.15 + 360) % 360;
    return lastHeading!;
  });
});

// ─── Smooth Device Pitch Provider (Low-Pass Filter) ─────────────────────────

/// Streams smoothed device pitch angle (-90° to +90°) to prevent up/down jumping ("auf und ab buggen").
final devicePitchProvider = StreamProvider.autoDispose<double>((ref) {
  double? lastPitch;

  return accelerometerEventStream().map((event) {
    // Calculate pitch from accelerometer forces (x, y, z)
    final rawPitchRad = atan2(event.z, sqrt(event.x * event.x + event.y * event.y));
    final rawPitchDeg = rawPitchRad * 180 / pi;

    if (lastPitch == null) {
      lastPitch = rawPitchDeg;
      return rawPitchDeg;
    }

    // Exponential Moving Average filter (alpha = 0.12 for silky smooth motion)
    lastPitch = lastPitch! * 0.88 + rawPitchDeg * 0.12;
    return lastPitch!;
  });
});

// ─── Derived State ───────────────────────────────────────────────────────────

final windRelativeAngleProvider = Provider<double>((ref) {
  final heading = ref.watch(compassHeadingProvider).valueOrNull ?? 0.0;
  final weather = ref.watch(weatherDataProvider).valueOrNull;
  if (weather == null) return 0.0;

  return (weather.windDirection - heading + 360) % 360;
});
