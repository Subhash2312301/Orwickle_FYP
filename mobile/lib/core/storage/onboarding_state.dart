import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers on this device whether the intro slides have been shown, so they appear only once.
/// Kept apart from the token storage because logging out must not show the slides again.
class OnboardingState extends ChangeNotifier {
  OnboardingState([this._storage = const FlutterSecureStorage()]);

  static const _key = 'orwickle_onboarding_seen';
  final FlutterSecureStorage _storage;

  bool _seen = false;
  bool get seen => _seen;

  /// Called once at app start, before the first screen is chosen.
  Future<void> load() async {
    try {
      _seen = await _storage.read(key: _key) == 'yes';
    } catch (_) {
      _seen = false; // unreadable storage: showing the slides again is harmless
    }
  }

  Future<void> markSeen() async {
    _seen = true;
    notifyListeners();
    try {
      await _storage.write(key: _key, value: 'yes');
    } catch (_) {
      // not saved: the slides come back on the next start, nothing else breaks
    }
  }
}
