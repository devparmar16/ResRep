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

    // If you are connecting an Android device via USB debugging, the most foolproof
    // way to connect without Wi-Fi issues is using `adb reverse`. In this case, 
    // the phone's localhost will seamlessly map to your computer's localhost.
    return 'http://127.0.0.1:8000';
  }

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
