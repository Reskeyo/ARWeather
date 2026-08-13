import 'package:flutter/material.dart';
import '../../models/weather_data.dart';

/// Displays the primary weather information in a sleek header layout.
///
/// Shows the large temperature reading, condition icon, and description text.
class WeatherHeader extends StatelessWidget {
  final WeatherData weather;

  const WeatherHeader({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Condition icon (emoji)
        Text(
          weather.conditionIcon,
          style: const TextStyle(fontSize: 52),
        ),
        const SizedBox(height: 8),

        // Temperature
        Text(
          '${weather.temperature.round()}°',
          style: const TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.w200,
            color: Colors.white,
            letterSpacing: -2,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),

        // Condition text
        Text(
          weather.conditionText,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.85),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
