import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_config.dart';

/// The backend address this device talks to. Starts as the build-time [AppConfig.apiBaseUrl];
/// can be changed in the app (login / welcome screen) so one APK works on any Wi-Fi or hotspot.
class ServerAddress {
  const ServerAddress._();

  static const _key = 'orwickle_server_address';
  static const _storage = FlutterSecureStorage();
  static const _defaultPort = 4000;

  static final ValueNotifier<String> current = ValueNotifier(AppConfig.apiBaseUrl);

  static String get url => current.value;

  /// "192.168.43.5:4000", for showing to the user.
  static String get display {
    final uri = Uri.tryParse(url);
    return uri == null || uri.host.isEmpty ? url : '${uri.host}:${uri.port}';
  }

  /// Called once at app start.
  static Future<void> load() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved != null && saved.isNotEmpty) current.value = saved;
    } catch (_) {
      // unreadable storage: keep the build-time address
    }
  }

  /// Accepts "192.168.43.5", "192.168.43.5:4000" or a full "http://…/api" URL.
  /// Returns null when [input] is not a usable address.
  static String? normalize(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'http://$text';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty || !(uri.scheme == 'http' || uri.scheme == 'https')) return null;
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : _defaultPort);
    final path = uri.path.isEmpty || uri.path == '/' ? '/api' : uri.path.replaceAll(RegExp(r'/+$'), '');
    return Uri(scheme: uri.scheme, host: uri.host, port: port, path: path).toString();
  }

  static Future<void> save(String url) async {
    current.value = url;
    try {
      await _storage.write(key: _key, value: url);
    } catch (_) {
      // not saved: the address lasts until the app restarts
    }
  }

  static Future<void> reset() async {
    current.value = AppConfig.apiBaseUrl;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
