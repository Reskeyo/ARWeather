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

enum DemoWeatherMode { live, storm, windy, snow }

List<WeatherGridPoint> _generateSimulatedGrid(
  double userLat,
  double userLon,
  DemoWeatherMode mode,
) {
  final List<WeatherGridPoint> points = [];
  const offsets = [-0.04, -0.02, 0.0, 0.02, 0.04];

  for (final dx in offsets) {
    for (final dy in offsets) {
      if (dx == 0.0 && dy == 0.0) continue;
      final lat = userLat + dx;
      final lon = userLon + dy;

      WeatherData w;
      switch (mode) {
        case DemoWeatherMode.storm:
          w = WeatherData(
            temperature: 16.0,
            cloudCover: 90.0,
            windDirection: 240.0,
            windSpeed: 38.0,
            rain: 8.5,
            weatherCode: 63, // Heavy Rain
            latitude: lat,
            longitude: lon,
          );
          break;
        case DemoWeatherMode.windy:
          w = WeatherData(
            temperature: 18.0,
            cloudCover: 75.0,
            windDirection: 310.0,
            windSpeed: 45.0,
            rain: 0.5,
            weatherCode: 3,
            latitude: lat,
            longitude: lon,
          );
          break;
        case DemoWeatherMode.snow:
          w = WeatherData(
            temperature: -2.0,
            cloudCover: 85.0,
            windDirection: 45.0,
            windSpeed: 22.0,
            rain: 0.0,
            weatherCode: 73, // Snow
            latitude: lat,
            longitude: lon,
          );
          break;
        case DemoWeatherMode.live:
        default:
          w = WeatherData(
            temperature: 20.0,
            cloudCover: 60.0 + (dx.abs() + dy.abs()) * 400,
            windDirection: 210.0,
            windSpeed: 18.0,
            rain: (dx > 0) ? 1.5 : 0.0,
            weatherCode: (dx > 0) ? 61 : 2,
            latitude: lat,
            longitude: lon,
          );
          break;
      }

      points.add(WeatherGridPoint(
        latitude: lat,
        longitude: lon,
        weather: w,
      ));
    }
  }

  return points;
}

class ARWeatherScreen extends ConsumerStatefulWidget {
  const ARWeatherScreen({super.key});

  @override
  ConsumerState<ARWeatherScreen> createState() => _ARWeatherScreenState();
}

class _ARWeatherScreenState extends ConsumerState<ARWeatherScreen> {
  Timer? _refreshTimer;
  DemoWeatherMode _activeMode = DemoWeatherMode.live;

  @override
  void initState() {
    super.initState();
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

    final gridData = weatherGridAsync.valueOrNull;

    WeatherData centerWeather;
    if (_activeMode == DemoWeatherMode.storm) {
      centerWeather = const WeatherData(
        temperature: 16.0,
        cloudCover: 90.0,
        windDirection: 240.0,
        windSpeed: 38.0,
        rain: 8.5,
        weatherCode: 63,
      );
    } else if (_activeMode == DemoWeatherMode.windy) {
      centerWeather = const WeatherData(
        temperature: 18.0,
        cloudCover: 75.0,
        windDirection: 310.0,
        windSpeed: 45.0,
        rain: 0.5,
        weatherCode: 3,
      );
    } else if (_activeMode == DemoWeatherMode.snow) {
      centerWeather = const WeatherData(
        temperature: -2.0,
        cloudCover: 85.0,
        windDirection: 45.0,
        windSpeed: 22.0,
        rain: 0.0,
        weatherCode: 73,
      );
    } else {
      centerWeather = gridData?.centerWeather ??
          const WeatherData(
            temperature: 21.0,
            cloudCover: 55.0,
            windDirection: 225.0,
            windSpeed: 16.0,
            rain: 0.0,
            weatherCode: 2,
          );
    }

    final userLat = centerWeather.latitude != 0.0 ? centerWeather.latitude : 52.52;
    final userLon = centerWeather.longitude != 0.0 ? centerWeather.longitude : 13.41;

    final gridPoints = (_activeMode != DemoWeatherMode.live)
        ? _generateSimulatedGrid(userLat, userLon, _activeMode)
        : (gridData?.gridPoints ?? _generateSimulatedGrid(userLat, userLon, DemoWeatherMode.live));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Live Camera Feed ──
          const CameraLayer(),

          // ── Layer 2: True AR Spatial Weather Overlay with Wind Streams ──
          WeatherOverlay(
            userLat: userLat,
            userLon: userLon,
            gridPoints: gridPoints,
            heading: compassHeading,
            pitch: devicePitch,
            centerWeather: centerWeather,
          ),

          // ── Layer 3: Glassmorphism UI Controls ──
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(compassHeading, windAngle, centerWeather),

                // Interactive Weather Mode Selector (LIVE / STORM / WINDY / SNOW)
                _buildModeSelector(),

                const Spacer(),

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

          WindDirectionIndicator(
            relativeWindAngle: windAngle,
            speedLabel: '${weather.windSpeed.round()} km/h',
            directionLabel: weather.windDirectionLabel,
          ),
        ],
      ),
    );
  }

  /// Interactive pill bar allowing instant testing of Storm, Wind, Snow, or Live weather.
  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildModeChip('📍 Live', DemoWeatherMode.live),
            const SizedBox(width: 8),
            _buildModeChip('⛈️ Storm', DemoWeatherMode.storm),
            const SizedBox(width: 8),
            _buildModeChip('💨 Windy', DemoWeatherMode.windy),
            const SizedBox(width: 8),
            _buildModeChip('❄️ Snow', DemoWeatherMode.snow),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(String label, DemoWeatherMode mode) {
    final isSelected = _activeMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _activeMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withOpacity(0.85)
              : Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF818CF8)
                : Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: Colors.white,
          ),
        ),
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
                if (isLoading && _activeMode == DemoWeatherMode.live)
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
