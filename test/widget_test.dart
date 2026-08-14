import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ar_weather/models/weather_data.dart';
import 'package:ar_weather/utils/ar_projection.dart';

void main() {
  group('WeatherData Model Tests', () {
    test('Parses Open-Meteo JSON correctly', () {
      final sampleJson = {
        'current': {
          'temperature_2m': 22.5,
          'cloud_cover': 65.0,
          'wind_direction_10m': 180.0,
          'wind_speed_10m': 14.2,
          'rain': 1.5,
          'weather_code': 61,
        }
      };

      final data = WeatherData.fromOpenMeteo(sampleJson, lat: 52.52, lon: 13.41);

      expect(data.temperature, 22.5);
      expect(data.cloudCover, 65.0);
      expect(data.windDirection, 180.0);
      expect(data.windSpeed, 14.2);
      expect(data.rain, 1.5);
      expect(data.weatherCode, 61);
      expect(data.conditionText, 'Rain');
      expect(data.windDirectionLabel, 'S');
    });
  });

  group('AR Projection Math & Roll Compensation Tests', () {
    const screenSize = Size(400, 800);

    test('Distance and bearing calculations are accurate', () {
      // Distance from (0, 0) to (0, 1) degree longitude at equator is approx 111.3 km
      final dist = ARProjection.distanceBetween(0.0, 0.0, 0.0, 1.0);
      expect(dist, greaterThan(110000.0));
      expect(dist, lessThan(112000.0));

      // Bearing from (0, 0) due East to (0, 1) is 90°
      final bearingEast = ARProjection.bearingTo(0.0, 0.0, 0.0, 1.0);
      expect(bearingEast, closeTo(90.0, 0.1));

      // Bearing from (0, 0) due North to (1, 0) is 0°
      final bearingNorth = ARProjection.bearingTo(0.0, 0.0, 1.0, 0.0);
      expect(bearingNorth, closeTo(0.0, 0.1));
    });

    test('Horizon centered when level (pitch = 0, roll = 0)', () {
      final proj = ARProjection.projectSphericalToScreen(
        azimuthDegrees: 0.0,
        elevationDegrees: 0.0,
        deviceHeading: 0.0,
        devicePitch: 0.0,
        deviceRoll: 0.0,
        screenSize: screenSize,
      );

      expect(proj.isVisible, true);
      expect(proj.x, closeTo(200.0, 0.1));
      expect(proj.y, closeTo(400.0, 0.1));
    });

    test('Pitching up moves horizon down on screen', () {
      final proj = ARProjection.projectSphericalToScreen(
        azimuthDegrees: 0.0,
        elevationDegrees: 0.0,
        deviceHeading: 0.0,
        devicePitch: 20.0, // Looking up 20°
        deviceRoll: 0.0,
        screenSize: screenSize,
      );

      expect(proj.isVisible, true);
      expect(proj.y, greaterThan(400.0)); // Horizon moves down
    });

    test('Rolling right rotates points correctly around viewport center', () {
      // An object directly to the right along horizon
      final projUnrolled = ARProjection.projectSphericalToScreen(
        azimuthDegrees: 15.0,
        elevationDegrees: 0.0,
        deviceHeading: 0.0,
        devicePitch: 0.0,
        deviceRoll: 0.0,
        screenSize: screenSize,
      );

      final projRolledRight = ARProjection.projectSphericalToScreen(
        azimuthDegrees: 15.0,
        elevationDegrees: 0.0,
        deviceHeading: 0.0,
        devicePitch: 0.0,
        deviceRoll: 30.0, // Tilted right 30°
        screenSize: screenSize,
      );

      expect(projUnrolled.isVisible, true);
      expect(projRolledRight.isVisible, true);
      // When rolled right (+30°), the right side of the scene dips down (+Y)
      expect(projRolledRight.y, greaterThan(projUnrolled.y));
    });
  });
}

