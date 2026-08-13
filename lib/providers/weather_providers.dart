import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weather_data.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import '../services/compass_service.dart';

// ─── Service Providers ───────────────────────────────────────────────────────

/// Provides a singleton [WeatherService] instance.
final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});

/// Provides a singleton [LocationService] instance.
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Provides a singleton [CompassService] instance.
final compassServiceProvider = Provider<CompassService>((ref) {
  return CompassService();
});

// ─── Weather Data Provider ───────────────────────────────────────────────────

/// Async provider that fetches weather data based on current GPS location.
///
/// Auto-refreshes every 5 minutes via the [weatherRefreshProvider].
final weatherDataProvider = FutureProvider.autoDispose<WeatherData>((ref) async {
  // Watch the refresh trigger to auto-refresh
  ref.watch(weatherRefreshProvider);

  final locationService = ref.read(locationServiceProvider);
  final weatherService = ref.read(weatherServiceProvider);

  final position = await locationService.getCurrentPosition();

  return weatherService.fetchWeather(
    latitude: position.latitude,
    longitude: position.longitude,
  );
});

/// A simple state provider that can be incremented to trigger weather refresh.
final weatherRefreshProvider = StateProvider<int>((ref) => 0);

// ─── Compass Heading Provider ────────────────────────────────────────────────

/// Streams the current compass heading in degrees (0-360).
final compassHeadingProvider = StreamProvider<double>((ref) {
  final compassService = ref.read(compassServiceProvider);
  return compassService.headingStream;
});

// ─── Derived State ───────────────────────────────────────────────────────────

/// Computes the angle between the wind direction and the device's heading.
///
/// This is used to position 3D weather effects relative to where the user
/// is looking — clouds should appear to come from the real wind direction.
final windRelativeAngleProvider = Provider<double>((ref) {
  final heading = ref.watch(compassHeadingProvider).valueOrNull ?? 0.0;
  final weather = ref.watch(weatherDataProvider).valueOrNull;
  if (weather == null) return 0.0;

  // Wind direction is "where wind comes FROM" (meteorological convention).
  // We compute the relative angle: how many degrees to the right of
  // the user's current heading the wind is coming from.
  return (weather.windDirection - heading + 360) % 360;
});
