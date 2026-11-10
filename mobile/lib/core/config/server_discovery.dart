import 'dart:async';

import 'package:flutter/foundation.dart';

import 'discovery_probe_stub.dart' if (dart.library.io) 'discovery_probe_io.dart' as probe;
import 'app_config.dart';
import 'server_address.dart';

/// Finds the laptop running the backend on whatever Wi-Fi or hotspot the phone is on, so the
/// IP address never has to be typed in.
///
/// The saved address is tried first. If nothing answers there, every address of the phone's own
/// network (x.x.x.1 to x.x.x.254) is asked for /api/health on port 4000, and the first one that
/// answers as "orwickle" is saved.
class ServerDiscovery {
  const ServerDiscovery._();

  static const port = 4000;
  static const _checkTimeout = Duration(seconds: 2);
  static const _scanTimeout = Duration(milliseconds: 1500);
  static const _batchSize = 128;

  static Future<bool>? _running;

  /// Makes sure [ServerAddress.url] points at a running backend. Returns false when none was found.
  static Future<bool> ensure() => _running ??= _ensure().whenComplete(() => _running = null);

  static Future<bool> _ensure() async {
    if (kIsWeb) return true; // the web build talks to the address it was built with
    if (await probe.isOrwickle(ServerAddress.url, _checkTimeout)) return true;

    final found = await _scan();
    if (found != null) {
      await ServerAddress.save(found);
      return true;
    }
    return false;
  }

  static Future<String?> _scan() async {
    final urls = <String>{
      // the address the APK was built with, e.g. the laptop's home IP
      if (AppConfig.apiBaseUrl != ServerAddress.url) AppConfig.apiBaseUrl,
      for (final host in await probe.networkHosts()) 'http://$host:$port/api',
    }.toList();

    for (var i = 0; i < urls.length; i += _batchSize) {
      final batch = urls.sublist(i, i + _batchSize > urls.length ? urls.length : i + _batchSize);
      final found = await _firstOrwickle(batch);
      if (found != null) return found;
    }
    return null;
  }

  /// Asks every url at once and finishes as soon as one answers as the backend.
  static Future<String?> _firstOrwickle(List<String> urls) {
    final result = Completer<String?>();
    var left = urls.length;
    for (final url in urls) {
      probe.isOrwickle(url, _scanTimeout).then((ok) {
        left--;
        if (result.isCompleted) return;
        if (ok) {
          result.complete(url);
        } else if (left == 0) {
          result.complete(null);
        }
      });
    }
    return result.future;
  }
}
