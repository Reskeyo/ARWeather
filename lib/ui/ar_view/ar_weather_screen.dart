import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/weather_data.dart';
import '../../providers/weather_providers.dart';
import '../widgets/glass_card.dart';
import '../widgets/weather_header.dart';
import '../widgets/metric_badge.dart';
import '../widgets/wind_direction_indicator.dart';
import 'camera_layer.dart';
import 'weather_overlay.dart';

/// Fallback spatial grid generated around default coordinates for initial load / demo state.
List<WeatherGridPoint> _generateFallbackGrid(double userLat, double userLon) {
  final List<WeatherGridPoint> points = [];
  const offsets = [-0.04, -0.02, 0.0, 0.02, 0.04];

  for (final dx in offsets) {
    for (final dy in offsets) {
      if (dx == 0.0 && dy == 0.0) continue; // skip center
      final lat = userLat + dx;
      final lon = userLon + dy;
      points.add(WeatherGridPoint(
        latitude: lat,
        longitude: lon,
        weather: WeatherData(
          temperature: 20.0,
          cloudCover: 60.0 + (dx.abs() + dy.abs()) * 500,
          windDirection: 210.0,
          windSpeed: 18.0,
          rain: (dx > 0) ? 1.5 : 0.0,
          weatherCode: (dx > 0) ? 61 : 2,
          latitude: lat,
          longitude: lon,
        ),
      ));
    }
  }

  return points;
}

/// The main AR Weather screen — composites live camera feed, True AR spatial 3D weather radar,
/// and compact glassmorphism UI overlays into a real-time experience.
class ARWeatherScreen extends ConsumerStatefulWidget {
  const ARWeatherScreen({super.key});

  @override
  ConsumerState<ARWeatherScreen> createState() => _ARWeatherScreenState();
}

class _ARWeatherScreenState extends ConsumerState<ARWeatherScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh weather grid every 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      ref.read(weatherRefreshProvider.notifier).state++;
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weatherGridAsync = ref.watch(weatherGridProvider);
    final compassHeading = ref.watch(compassHeadingProvider).valueOrNull ?? 0.0;
    final devicePitch = ref.watch(devicePitchProvider).valueOrNull ?? 0.0;
    final windAngle = ref.watch(windRelativeAngleProvider);

    // Extract center weather & spatial grid points
    final gridData = weatherGridAsync.valueOrNull;
    final centerWeather = gridData?.centerWeather ??
        const WeatherData(
          temperature: 21.0,
          cloudCover: 55.0,
          windDirection: 225.0,
          windSpeed: 16.0,
          rain: 0.0,
          weatherCode: 2,
        );

    final userLat = centerWeather.latitude != 0.0 ? centerWeather.latitude : 52.52;
    final userLon = centerWeather.longitude != 0.0 ? centerWeather.longitude : 13.41;

    final gridPoints = gridData?.gridPoints ?? _generateFallbackGrid(userLat, userLon);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Live Camera Feed ──
          const CameraLayer(),

          // ── Layer 2: True AR Spatial Weather Overlay ──
          WeatherOverlay(
            userLat: userLat,
            userLon: userLon,
            gridPoints: gridPoints,
            heading: compassHeading,
            pitch: devicePitch,
          ),

          // ── Layer 3: Glassmorphism UI Controls & Overlay ──
          SafeArea(
            child: Column(
              children: [
                // Top Bar with Compass Heading & Wind Compass
                _buildTopBar(compassHeading, windAngle, centerWeather),

                const Spacer(),

                // Bottom Floating Glass Weather Bar
                _buildCompactBottomBar(centerWeather, weatherGridAsync.isLoading),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    double compassHeading,
    double windAngle,
    WeatherData weather,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            borderRadius: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.radar,
                  color: Color(0xFF38BDF8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'True AR Radar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${compassHeading.round()}° ${weather.windDirectionLabel} • ${weather.conditionText}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.65),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Wind direction compass indicator
          WindDirectionIndicator(
            relativeWindAngle: windAngle,
            speedLabel: '${weather.windSpeed.round()} km/h',
            directionLabel: weather.windDirectionLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBottomBar(WeatherData weather, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: 22,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: WeatherHeader(weather: weather),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                MetricBadge(
                  icon: Icons.air,
                  value: '${weather.windSpeed.round()}',
                  label: 'km/h',
                  iconColor: const Color(0xFF818CF8),
                ),
                MetricBadge(
                  icon: Icons.water_drop_outlined,
                  value: '${weather.rain}',
                  label: 'mm',
                  iconColor: const Color(0xFF38BDF8),
                ),
                MetricBadge(
                  icon: Icons.cloud_outlined,
                  value: '${weather.cloudCover.round()}%',
                  label: 'Clouds',
                  iconColor: Colors.white70,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
