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

/// Async provider fetching single-location weather data.
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

/// Async provider fetching a spatial grid of 25 weather points around the user's GPS position.
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

/// Refresh trigger provider.
final weatherRefreshProvider = StateProvider<int>((ref) => 0);

// ─── Compass Heading Provider ────────────────────────────────────────────────

final compassHeadingProvider = StreamProvider<double>((ref) {
  final compassService = ref.read(compassServiceProvider);
  return compassService.headingStream;
});

// ─── Device Pitch / Tilt Provider ───────────────────────────────────────────

/// Streams the device's pitch (vertical tilt angle in degrees).
///
/// 0° = vertical/horizontal facing horizon.
/// +45° = tilting phone up towards the sky.
/// -45° = tilting phone down towards the ground.
final devicePitchProvider = StreamProvider.autoDispose<double>((ref) {
  return accelerometerEventStream().map((event) {
    // Calculate pitch from accelerometer forces (x, y, z)
    final pitchRad = atan2(event.z, sqrt(event.x * event.x + event.y * event.y));
    return pitchRad * 180 / pi;
  });
});

// ─── Derived State ───────────────────────────────────────────────────────────

final windRelativeAngleProvider = Provider<double>((ref) {
  final heading = ref.watch(compassHeadingProvider).valueOrNull ?? 0.0;
  final weather = ref.watch(weatherDataProvider).valueOrNull;
  if (weather == null) return 0.0;

  return (weather.windDirection - heading + 360) % 360;
});
