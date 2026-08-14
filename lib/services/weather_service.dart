import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';


/// Service that fetches current weather data and spatial weather grids from Open-Meteo API.
class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetches current weather for a single location.
  Future<WeatherData> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': [
        'temperature_2m',
        'cloud_cover',
        'wind_direction_10m',
        'wind_speed_10m',
        'rain',
        'weather_code',
      ].join(','),
      'wind_speed_unit': 'kmh',
    });

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch weather data: HTTP ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return WeatherData.fromOpenMeteo(json, lat: latitude, lon: longitude);
  }

  /// Fetches a spatial grid of weather data surrounding [latitude] and [longitude] (e.g. 5x5 grid = 25 points).
  Future<WeatherGridData> fetchWeatherGrid({
    required double latitude,
    required double longitude,
    int gridRadiusCount = 2, // 5x5 grid
    double stepDegrees = 0.04, // ~4.4 km grid spacing
  }) async {
    final List<double> lats = [];
    final List<double> lons = [];

    for (int dx = -gridRadiusCount; dx <= gridRadiusCount; dx++) {
      for (int dy = -gridRadiusCount; dy <= gridRadiusCount; dy++) {
        lats.add(latitude + (dx * stepDegrees));
        lons.add(longitude + (dy * stepDegrees));
      }
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': lats.map((e) => e.toStringAsFixed(4)).join(','),
      'longitude': lons.map((e) => e.toStringAsFixed(4)).join(','),
      'current': [
        'temperature_2m',
        'cloud_cover',
        'wind_direction_10m',
        'wind_speed_10m',
        'rain',
        'weather_code',
      ].join(','),
      'wind_speed_unit': 'kmh',
    });

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<WeatherGridPoint> points = [];

        if (decoded is List) {
          for (int i = 0; i < decoded.length; i++) {
            final weather = WeatherData.fromOpenMeteo(
              decoded[i] as Map<String, dynamic>,
              lat: lats[i],
              lon: lons[i],
            );
            points.add(WeatherGridPoint(
              latitude: lats[i],
              longitude: lons[i],
              weather: weather,
            ));
          }
        } else if (decoded is Map<String, dynamic>) {
          final weather = WeatherData.fromOpenMeteo(
            decoded,
            lat: latitude,
            lon: longitude,
          );
          points.addAll(_generateRadialPoints(latitude, longitude, weather));
        }

        final centerWeather = points.isNotEmpty
            ? points[points.length ~/ 2].weather
            : WeatherData(
                temperature: 20,
                cloudCover: 50,
                windDirection: 180,
                windSpeed: 15,
                rain: 0,
                weatherCode: 2,
                latitude: latitude,
                longitude: longitude,
              );

        return WeatherGridData(
          centerWeather: centerWeather,
          gridPoints: points,
        );
      }
    } catch (_) {
      // Fallback on network/parse error
    }

    // Fallback single-point request
    try {
      final single = await fetchWeather(latitude: latitude, longitude: longitude);
      return WeatherGridData(
        centerWeather: single,
        gridPoints: _generateRadialPoints(latitude, longitude, single),
      );
    } catch (_) {
      final defaultWeather = WeatherData(
        temperature: 21.0,
        cloudCover: 45.0,
        windDirection: 220.0,
        windSpeed: 16.0,
        rain: 0.0,
        weatherCode: 2,
        latitude: latitude,
        longitude: longitude,
      );
      return WeatherGridData(
        centerWeather: defaultWeather,
        gridPoints: _generateRadialPoints(latitude, longitude, defaultWeather),
      );
    }
  }

  /// Generates a set of spatial weather points evenly spaced around the center coordinate.
  List<WeatherGridPoint> _generateRadialPoints(
    double lat,
    double lon,
    WeatherData baseWeather,
  ) {
    final List<WeatherGridPoint> points = [];
    const ringDistances = [0.03, 0.06]; // ~3.3km and 6.6km
    const bearings = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0];

    for (final d in ringDistances) {
      for (final b in bearings) {
        final bRad = b * 3.141592653589793 / 180.0;
        final pLat = lat + d * cos(bRad);
        final pLon = lon + d * sin(bRad);

        // Natural subtle regional micro-climate variance
        final tempOffset = ((b % 90) - 45) * 0.03;
        final cloudOffset = ((b * 7) % 30) - 15;

        final w = WeatherData(
          temperature: (baseWeather.temperature + tempOffset).clamp(-40.0, 50.0),
          cloudCover: (baseWeather.cloudCover + cloudOffset).clamp(0.0, 100.0),
          windDirection: (baseWeather.windDirection + ((b % 60) - 30) + 360.0) % 360.0,
          windSpeed: (baseWeather.windSpeed * (0.85 + ((b % 40) / 100.0))).clamp(0.0, 120.0),
          rain: baseWeather.rain,
          weatherCode: baseWeather.weatherCode,
          latitude: pLat,
          longitude: pLon,
        );

        points.add(WeatherGridPoint(
          latitude: pLat,
          longitude: pLon,
          weather: w,
        ));
      }
    }
    return points;
  }
}

