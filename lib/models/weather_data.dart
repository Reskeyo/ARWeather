/// Data model representing current weather conditions at a specific location.
class WeatherData {
  final double temperature;
  final double cloudCover;
  final double windDirection;
  final double windSpeed;
  final double rain;
  final int weatherCode;
  final double latitude;
  final double longitude;

  const WeatherData({
    required this.temperature,
    required this.cloudCover,
    required this.windDirection,
    required this.windSpeed,
    required this.rain,
    required this.weatherCode,
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  factory WeatherData.fromOpenMeteo(
    Map<String, dynamic> json, {
    double lat = 0.0,
    double lon = 0.0,
  }) {
    final current = json['current'] as Map<String, dynamic>;
    return WeatherData(
      temperature: (current['temperature_2m'] as num).toDouble(),
      cloudCover: (current['cloud_cover'] as num).toDouble(),
      windDirection: (current['wind_direction_10m'] as num).toDouble(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      rain: (current['rain'] as num?)?.toDouble() ?? 0.0,
      weatherCode: (current['weather_code'] as num).toInt(),
      latitude: lat,
      longitude: lon,
    );
  }

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

  String get windDirectionLabel {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((windDirection + 22.5) % 360 / 45).floor();
    return directions[index];
  }
}

/// A spatial grid point holding localized weather data around the user.
class WeatherGridPoint {
  final double latitude;
  final double longitude;
  final WeatherData weather;

  const WeatherGridPoint({
    required this.latitude,
    required this.longitude,
    required this.weather,
  });
}

/// Grid collection of weather points surrounding the user for spatial AR projection.
class WeatherGridData {
  final WeatherData centerWeather;
  final List<WeatherGridPoint> gridPoints;

  const WeatherGridData({
    required this.centerWeather,
    required this.gridPoints,
  });
}
