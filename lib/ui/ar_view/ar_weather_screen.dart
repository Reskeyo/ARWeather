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

/// Fallback demo weather used during initial load or if GPS/API is unavailable,
/// ensuring AR 3D particle effects and UI are ALWAYS active instantly.
const _defaultWeather = WeatherData(
  temperature: 21.0,
  cloudCover: 55.0,
  windDirection: 225.0,
  windSpeed: 16.0,
  rain: 0.0,
  weatherCode: 2, // Partly Cloudy
);

/// The main AR Weather screen — composites the camera feed, 3D weather particle
/// overlay, and compact glassmorphism UI overlays into an immersive AR view.
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
    // Auto-refresh weather every 5 minutes
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
    final weatherAsync = ref.watch(weatherDataProvider);
    final windAngle = ref.watch(windRelativeAngleProvider);
    final compassHeading = ref.watch(compassHeadingProvider);

    // Active weather model (uses fetched data or fallback demo weather)
    final weather = weatherAsync.valueOrNull ?? _defaultWeather;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Live Camera Feed ──
          const CameraLayer(),

          // ── Layer 2: 3D AR Weather Particle Overlay (ALWAYS ACTIVE) ──
          WeatherOverlay(
            cloudCover: weather.cloudCover,
            rain: weather.rain,
            weatherCode: weather.weatherCode,
            windAngle: windAngle,
            windSpeed: weather.windSpeed,
          ),

          // ── Layer 3: Glassmorphism UI Overlay ──
          SafeArea(
            child: Column(
              children: [
                // Compact Top Bar with Compass & Wind Direction
                _buildTopBar(windAngle, compassHeading, weather),

                const Spacer(),

                // Compact Floating Bottom Glass Weather Bar (~15% height)
                _buildCompactBottomBar(weather, weatherAsync.isLoading),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the top navigation bar with compass heading and wind compass.
  Widget _buildTopBar(
    double windAngle,
    AsyncValue<double> compassHeading,
    WeatherData weather,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title & Compass Heading
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            borderRadius: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.explore_outlined,
                  color: Color(0xFF818CF8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'AR Weather',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      compassHeading.when(
                        data: (h) => '${h.round()}° ${weather.windDirectionLabel}',
                        loading: () => 'Calibrating…',
                        error: (_, __) => 'Heading N/A',
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Wind direction compass widget
          WindDirectionIndicator(
            relativeWindAngle: windAngle,
            speedLabel: '${weather.windSpeed.round()} km/h',
            directionLabel: weather.windDirectionLabel,
          ),
        ],
      ),
    );
  }

  /// Builds a super compact, non-intrusive bottom weather glass bar.
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
                // Temperature & Condition
                Expanded(
                  child: WeatherHeader(weather: weather),
                ),

                // Refreshing spinner indicator if active
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF818CF8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Horizontal Pill Badges for Wind, Rain, Cloud metrics
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
