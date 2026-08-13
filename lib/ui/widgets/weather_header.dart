import 'package:flutter/material.dart';
import '../../models/weather_data.dart';

/// Compact weather header for the AR overlay UI.
class WeatherHeader extends StatelessWidget {
  final WeatherData weather;

  const WeatherHeader({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Condition Icon
        Text(
          weather.conditionIcon,
          style: const TextStyle(fontSize: 36),
        ),
        const SizedBox(width: 10),

        // Temperature & Condition Text
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${weather.temperature.round()}°C',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                letterSpacing: -0.5,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              weather.conditionText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.85),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
