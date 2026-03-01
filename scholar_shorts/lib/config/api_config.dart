import 'package:flutter/foundation.dart' show kIsWeb;

/// Backend API configuration.
class ApiConfig {
  // For Android emulator: use 10.0.2.2 to reach host machine's localhost.
  // For web or iOS simulator: use localhost.
  // For physical device: use your machine's local IP.
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    // Web runs in the browser on the same machine as the backend
    if (kIsWeb) return 'http://localhost:8000';
    // Android emulator needs 10.0.2.2 to reach host's localhost
    // For physical device, using local IP address
    return 'http://192.168.0.104:8000';
  }

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
