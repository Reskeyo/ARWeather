import 'package:geolocator/geolocator.dart';

/// Service for obtaining the device's GPS location.
///
/// Handles permission requests and provides the current coordinates.
class LocationService {
  /// Returns the current device position.
  ///
  /// Requests location permissions if not already granted.
  /// Throws a [LocationServiceException] on failure.
  Future<Position> getCurrentPosition() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException('Location services are disabled.');
    }

    // Check and request permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationServiceException('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(
        'Location permission permanently denied. Please enable in Settings.',
      );
    }

    // Get current position with medium accuracy (good balance for weather).
    // geolocator 12.x: desiredAccuracy is a direct parameter.
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
  }
}

/// Custom exception for location service errors.
class LocationServiceException implements Exception {
  final String message;
  const LocationServiceException(this.message);

  @override
  String toString() => 'LocationServiceException: $message';
}
