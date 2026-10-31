import 'package:flutter/foundation.dart';

/// App-wide settings, chosen at build time with --dart-define.
///
///   flutter run                                                  → Android emulator → laptop backend
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:4000/api   → real phone on same Wi-Fi
///   flutter build web --dart-define=DEV_TOOLS=true               → keeps /system-check and /design-system
class AppConfig {
  const AppConfig._();

  /// 10.0.2.2 is how the Android emulator reaches the laptop's localhost.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:4000/api');

  static const Duration requestTimeout = Duration(seconds: 15);

  /// Developer pages (health check, component gallery): on in debug builds, off in releases
  /// unless DEV_TOOLS=true.
  static const bool devTools = bool.fromEnvironment('DEV_TOOLS', defaultValue: kDebugMode);
}
