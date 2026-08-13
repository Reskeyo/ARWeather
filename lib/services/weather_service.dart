import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

/// Service that fetches current weather data from the Open-Meteo API.
///
/// No API key required — uses the free Open-Meteo forecast endpoint.
class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetches current weather for the given [latitude] and [longitude].
  ///
  /// Returns a [WeatherData] model parsed from the API response.
  /// Throws an [Exception] if the request fails.
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
    return WeatherData.fromOpenMeteo(json);
  }
}
