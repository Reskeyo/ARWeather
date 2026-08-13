import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/weather_providers.dart';
import '../widgets/glass_card.dart';
import '../widgets/weather_header.dart';
import '../widgets/metric_badge.dart';
import '../widgets/wind_direction_indicator.dart';
import 'camera_layer.dart';
import 'weather_overlay.dart';

/// The main AR Weather screen — layers the camera feed, weather particle
/// effects, and glassmorphism UI overlays into a single immersive view.
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Camera Feed ──
          const CameraLayer(),

          // ── Layer 2: Weather Particle Effects ──
          weatherAsync.when(
            data: (weather) => WeatherOverlay(
              cloudCover: weather.cloudCover,
              rain: weather.rain,
              weatherCode: weather.weatherCode,
              windAngle: windAngle,
              windSpeed: weather.windSpeed,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ── Layer 3: UI Overlays ──
          SafeArea(
            child: Column(
              children: [
                // Top bar with compass & wind direction
                _buildTopBar(windAngle, compassHeading, weatherAsync),

                const Spacer(),

                // Bottom weather card
                _buildWeatherCard(weatherAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the top navigation bar with compass and wind indicator.
  Widget _buildTopBar(
    double windAngle,
    AsyncValue<double> compassHeading,
    AsyncValue weatherAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // App title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AR Weather',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                compassHeading.when(
                  data: (h) => 'Heading: ${h.round()}°',
                  loading: () => 'Calibrating…',
                  error: (_, __) => 'Compass N/A',
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),

          // Wind compass indicator
          weatherAsync.when(
            data: (weather) => WindDirectionIndicator(
              relativeWindAngle: windAngle,
              speedLabel: '${weather.windSpeed.round()} km/h',
              directionLabel: weather.windDirectionLabel,
            ),
            loading: () => const SizedBox(width: 100, height: 100),
            error: (_, __) => const SizedBox(width: 100, height: 100),
          ),
        ],
      ),
    );
  }

  /// Builds the main weather info card at the bottom of the screen.
  Widget _buildWeatherCard(AsyncValue weatherAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: weatherAsync.when(
        data: (weather) => GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Weather header (temp, icon, condition)
              WeatherHeader(weather: weather),
              const SizedBox(height: 24),

              // Divider
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0),
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Metric badges row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  MetricBadge(
                    icon: Icons.air,
                    value: '${weather.windSpeed.round()}',
                    label: 'km/h',
                    iconColor: const Color(0xFF6C63FF),
                  ),
                  MetricBadge(
                    icon: Icons.water_drop_outlined,
                    value: '${weather.rain}',
                    label: 'mm',
                    iconColor: const Color(0xFF4FC3F7),
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

        // Loading state
        loading: () => GlassCard(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF6C63FF),
                strokeWidth: 2,
              ),
              const SizedBox(height: 16),
              Text(
                'Fetching weather data…',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // Error state
        error: (error, _) => GlassCard(
          backgroundOpacity: 0.2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.redAccent.withOpacity(0.8),
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                'Could not load weather',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                error.toString(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  ref.read(weatherRefreshProvider.notifier).state++;
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6C63FF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
