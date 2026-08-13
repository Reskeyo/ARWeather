import 'dart:convert';
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
    double stepDegrees = 0.035, // ~3.5 km grid spacing
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
      'latitude': lats.map((e) => e.toString()).join(','),
      'longitude': lons.map((e) => e.toString()).join(','),
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
          points.add(WeatherGridPoint(
            latitude: latitude,
            longitude: longitude,
            weather: weather,
          ));
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
    final single = await fetchWeather(latitude: latitude, longitude: longitude);
    return WeatherGridData(
      centerWeather: single,
      gridPoints: [
        WeatherGridPoint(
          latitude: latitude,
          longitude: longitude,
          weather: single,
        ),
      ],
    );
  }
}
