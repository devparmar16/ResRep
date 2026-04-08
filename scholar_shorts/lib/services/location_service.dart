import 'package:geolocator/geolocator.dart';

/// Thin wrapper around [Geolocator] that handles permission checks
/// and returns a position or `null` with descriptive error messages.
class LocationService {
  /// Attempts to get the user's current GPS position.
  /// Returns `null` and populates [errorMessage] if anything fails.
  static String? lastError;

  static Future<Position?> getCurrentPosition() async {
    lastError = null;

    // 1. Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      lastError = 'Location services are disabled. Please enable GPS.';
      return null;
    }

    // 2. Check / request permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        lastError = 'Location permission denied. Please allow location access.';
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      lastError =
          'Location permission permanently denied. Please enable it in Settings.';
      return null;
    }

    // 3. Get current position
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return position;
    } catch (e) {
      lastError = 'Could not get location: $e';
      return null;
    }
  }

  /// Calculate distance in km between two coordinates (Haversine via Geolocator).
  static double distanceKm(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000.0;
  }
}
