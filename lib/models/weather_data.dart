/// Data model representing current weather conditions.
class WeatherData {
  /// Temperature in degrees Celsius.
  final double temperature;

  /// Cloud cover percentage (0-100).
  final double cloudCover;

  /// Wind direction in degrees (0 = North, 90 = East, etc.).
  final double windDirection;

  /// Wind speed in km/h.
  final double windSpeed;

  /// Rainfall in mm.
  final double rain;

  /// WMO Weather interpretation code.
  final int weatherCode;

  const WeatherData({
    required this.temperature,
    required this.cloudCover,
    required this.windDirection,
    required this.windSpeed,
    required this.rain,
    required this.weatherCode,
  });

  /// Creates a [WeatherData] instance from the Open-Meteo JSON response.
  factory WeatherData.fromOpenMeteo(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    return WeatherData(
      temperature: (current['temperature_2m'] as num).toDouble(),
      cloudCover: (current['cloud_cover'] as num).toDouble(),
      windDirection: (current['wind_direction_10m'] as num).toDouble(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      rain: (current['rain'] as num?)?.toDouble() ?? 0.0,
      weatherCode: (current['weather_code'] as num).toInt(),
    );
  }

  /// Returns a human-readable weather condition string based on WMO code.
  String get conditionText {
    if (weatherCode == 0) return 'Clear Sky';
    if (weatherCode <= 3) return 'Partly Cloudy';
    if (weatherCode <= 49) return 'Foggy';
    if (weatherCode <= 59) return 'Drizzle';
    if (weatherCode <= 69) return 'Rain';
    if (weatherCode <= 79) return 'Snow';
    if (weatherCode <= 84) return 'Rain Showers';
    if (weatherCode <= 86) return 'Snow Showers';
    if (weatherCode >= 95) return 'Thunderstorm';
    return 'Unknown';
  }

  /// Returns the appropriate icon for the current weather.
  String get conditionIcon {
    if (weatherCode == 0) return '☀️';
    if (weatherCode <= 3) return '⛅';
    if (weatherCode <= 49) return '🌫️';
    if (weatherCode <= 59) return '🌦️';
    if (weatherCode <= 69) return '🌧️';
    if (weatherCode <= 79) return '❄️';
    if (weatherCode <= 84) return '🌧️';
    if (weatherCode <= 86) return '🌨️';
    if (weatherCode >= 95) return '⛈️';
    return '🌡️';
  }

  /// Returns wind direction as a compass label (N, NE, E, etc.).
  String get windDirectionLabel {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((windDirection + 22.5) % 360 / 45).floor();
    return directions[index];
  }
}
