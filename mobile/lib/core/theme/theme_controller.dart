import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The user's light / dark / system choice, remembered on this device (Settings → Appearance).
class ThemeController extends ChangeNotifier {
  ThemeController([this._storage = const FlutterSecureStorage()]);

  static const _key = 'orwickle_theme_mode';
  final FlutterSecureStorage _storage;

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Called once at app start.
  Future<void> load() async {
    try {
      final saved = await _storage.read(key: _key);
      _mode = ThemeMode.values.where((m) => m.name == saved).firstOrNull ?? ThemeMode.system;
    } catch (_) {
      _mode = ThemeMode.system; // unreadable storage: follow the phone
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      await _storage.write(key: _key, value: mode.name);
    } catch (_) {
      // not saved: the choice lasts until the app restarts
    }
  }
}
