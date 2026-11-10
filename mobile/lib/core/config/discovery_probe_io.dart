// Phone / desktop: network checks used by ServerDiscovery.

import 'dart:convert';
import 'dart:io';

/// Whether [apiUrl] (e.g. http://192.168.1.5:4000/api) is the Orwickle backend.
Future<bool> isOrwickle(String apiUrl, Duration timeout) async {
  final uri = Uri.tryParse('$apiUrl/health');
  if (uri == null || uri.host.isEmpty) return false;
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(uri).timeout(timeout);
    final response = await request.close().timeout(timeout);
    final body = await response.transform(utf8.decoder).join().timeout(timeout);
    final json = jsonDecode(body);
    return json is Map && json['service'] == 'orwickle';
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

// mobile data, VPN and other links that never lead to the laptop
final _skipInterface = RegExp(r'^(rmnet|ccmni|pdp|tun|ppp|dummy|v4-|clat|ipsec|lo)', caseSensitive: false);

/// Every other address on the phone's Wi-Fi or hotspot networks (x.x.x.1 to x.x.x.254).
Future<List<String>> networkHosts() async {
  final List<NetworkInterface> interfaces;
  try {
    interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  } catch (_) {
    return const [];
  }
  final own = <String>{};
  final prefixes = <String>{};
  for (final interface in interfaces) {
    if (_skipInterface.hasMatch(interface.name)) continue;
    for (final address in interface.addresses) {
      final parts = address.address.split('.').map(int.tryParse).toList();
      if (parts.length != 4 || parts.contains(null) || !_isPrivate(parts[0]!, parts[1]!)) continue;
      own.add(address.address);
      prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
    }
  }
  return [
    for (final prefix in prefixes)
      for (var i = 1; i < 255; i++)
        if (!own.contains('$prefix.$i')) '$prefix.$i',
  ];
}

bool _isPrivate(int a, int b) => a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
