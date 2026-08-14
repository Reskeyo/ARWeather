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

enum DemoWeatherMode {
  live,
  partlyCloudy,
  overcast,
  storm,
  rain,
  windy,
  snow,
  clear,
}

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
            temperature: 16.0 + dx * 20,
            cloudCover: 95.0,
            windDirection: 240.0,
            windSpeed: 42.0,
            rain: 9.5,
            weatherCode: 95, // Thunderstorm
            latitude: lat,
            longitude: lon,
          );
          break;
        case DemoWeatherMode.rain:
          w = WeatherData(
            temperature: 15.0 + dx * 15,
            cloudCover: 90.0,
            windDirection: 210.0,
            windSpeed: 24.0,
            rain: 6.2,
            weatherCode: 63, // Rain
            latitude: lat,
            longitude: lon,
          );
          break;
        case DemoWeatherMode.windy:
          w = WeatherData(
            temperature: 18.0 + dy * 20,
            cloudCover: 65.0,
            windDirection: 310.0,
            windSpeed: 52.0,
            rain: 0.2,
            weatherCode: 3,
            latitude: lat,
            longitude: lon,
          );
          break;
        case DemoWeatherMode.snow:
          w = WeatherData(
            temperature: -2.0 + dx * 10,
            cloudCover: 85.0,
            windDirection: 45.0,
            windSpeed: 20.0,
            rain: 0.0,
            weatherCode: 73, // Snow
            latitude: lat,
            longitude: lon,
          );
          break;
        case DemoWeatherMode.overcast:
          w = WeatherData(
            temperature: 17.0 + dx * 10,
            cloudCover: 92.0,
            windDirection: 190.0,
            windSpeed: 16.0,
            rain: 0.1,
            weatherCode: 3,
            latitude: lat,
            longitude: lon,
          );
          break;
        case DemoWeatherMode.partlyCloudy:
          w = WeatherData(
            temperature: 23.0 + dx * 15,
            cloudCover: 45.0,
            windDirection: 220.0,
            windSpeed: 14.0,
            rain: 0.0,
            weatherCode: 2,
            latitude: lat,
            longitude: lon,
          );
          break;
        case DemoWeatherMode.clear:
          w = WeatherData(
            temperature: 27.0 + dx * 10,
            cloudCover: 0.0,
            windDirection: 160.0,
            windSpeed: 8.0,
            rain: 0.0,
            weatherCode: 0,
            latitude: lat,
            longitude: lon,
          );
          break;
        case DemoWeatherMode.live:
        default:
          w = WeatherData(
            temperature: 20.0 + dx * 20,
            cloudCover: 55.0 + (dx.abs() + dy.abs()) * 300,
            windDirection: 210.0,
            windSpeed: 18.0,
            rain: (dx > 0) ? 1.2 : 0.0,
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
  DemoWeatherMode _activeMode = DemoWeatherMode.partlyCloudy;

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
    final deviceRoll = ref.watch(deviceRollProvider).valueOrNull ?? 0.0;
    final windAngle = ref.watch(windRelativeAngleProvider);

    final gridData = weatherGridAsync.valueOrNull;

    WeatherData centerWeather;
    switch (_activeMode) {
      case DemoWeatherMode.storm:
        centerWeather = const WeatherData(
          temperature: 16.0,
          cloudCover: 95.0,
          windDirection: 240.0,
          windSpeed: 42.0,
          rain: 9.5,
          weatherCode: 95,
        );
        break;
      case DemoWeatherMode.rain:
        centerWeather = const WeatherData(
          temperature: 15.0,
          cloudCover: 90.0,
          windDirection: 210.0,
          windSpeed: 24.0,
          rain: 6.2,
          weatherCode: 63,
        );
        break;
      case DemoWeatherMode.windy:
        centerWeather = const WeatherData(
          temperature: 18.0,
          cloudCover: 65.0,
          windDirection: 310.0,
          windSpeed: 52.0,
          rain: 0.2,
          weatherCode: 3,
        );
        break;
      case DemoWeatherMode.snow:
        centerWeather = const WeatherData(
          temperature: -2.0,
          cloudCover: 85.0,
          windDirection: 45.0,
          windSpeed: 20.0,
          rain: 0.0,
          weatherCode: 73,
        );
        break;
      case DemoWeatherMode.overcast:
        centerWeather = const WeatherData(
          temperature: 17.0,
          cloudCover: 92.0,
          windDirection: 190.0,
          windSpeed: 16.0,
          rain: 0.1,
          weatherCode: 3,
        );
        break;
      case DemoWeatherMode.partlyCloudy:
        centerWeather = const WeatherData(
          temperature: 23.0,
          cloudCover: 45.0,
          windDirection: 220.0,
          windSpeed: 14.0,
          rain: 0.0,
          weatherCode: 2,
        );
        break;
      case DemoWeatherMode.clear:
        centerWeather = const WeatherData(
          temperature: 27.0,
          cloudCover: 0.0,
          windDirection: 160.0,
          windSpeed: 8.0,
          rain: 0.0,
          weatherCode: 0,
        );
        break;
      case DemoWeatherMode.live:
      default:
        centerWeather = gridData?.centerWeather ??
            const WeatherData(
              temperature: 22.0,
              cloudCover: 50.0,
              windDirection: 220.0,
              windSpeed: 15.0,
              rain: 0.0,
              weatherCode: 2,
            );
        break;
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

          // ── Layer 2: True AR Spatial Weather Overlay with Tilt-Compensated Horizon ──
          WeatherOverlay(
            userLat: userLat,
            userLon: userLon,
            gridPoints: gridPoints,
            heading: compassHeading,
            pitch: devicePitch,
            roll: deviceRoll,
            centerWeather: centerWeather,
          ),

          // ── Layer 3: Glassmorphism UI Controls ──
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(compassHeading, devicePitch, deviceRoll, windAngle, centerWeather),

                // Interactive Weather Mode Selector (LIVE / CLOUDS / OVERCAST / STORM / RAIN / WINDY / SNOW / CLEAR)
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
    double devicePitch,
    double deviceRoll,
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
                      'AR Weather 3D',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${compassHeading.round()}° ${weather.windDirectionLabel} • Pitch: ${devicePitch.round()}° • Roll: ${deviceRoll.round()}°',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.75),
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

  /// Interactive pill bar allowing instant testing of all weather conditions.
  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildModeChip('📍 Live', DemoWeatherMode.live),
            const SizedBox(width: 8),
            _buildModeChip('⛅ Clouds', DemoWeatherMode.partlyCloudy),
            const SizedBox(width: 8),
            _buildModeChip('☁️ Overcast', DemoWeatherMode.overcast),
            const SizedBox(width: 8),
            _buildModeChip('⛈️ Storm', DemoWeatherMode.storm),
            const SizedBox(width: 8),
            _buildModeChip('🌧️ Rain', DemoWeatherMode.rain),
            const SizedBox(width: 8),
            _buildModeChip('💨 Windy', DemoWeatherMode.windy),
            const SizedBox(width: 8),
            _buildModeChip('❄️ Snow', DemoWeatherMode.snow),
            const SizedBox(width: 8),
            _buildModeChip('☀️ Clear', DemoWeatherMode.clear),
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
              : Colors.black.withOpacity(0.4),
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

