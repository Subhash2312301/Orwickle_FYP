import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orwickle/core/config/discovery_probe_io.dart';

void main() {
  Future<HttpServer> serve(Object body) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body))
        ..close();
    });
    return server;
  }

  test('recognises the Orwickle backend by its health answer', () async {
    final server = await serve({'service': 'orwickle', 'status': 'ok'});
    addTearDown(() => server.close(force: true));
    expect(await isOrwickle('http://127.0.0.1:${server.port}/api', const Duration(seconds: 2)), isTrue);
  });

  test('ignores other servers and addresses where nothing runs', () async {
    final other = await serve({'status': 'ok'});
    addTearDown(() => other.close(force: true));
    expect(await isOrwickle('http://127.0.0.1:${other.port}/api', const Duration(seconds: 2)), isFalse);
    expect(await isOrwickle('http://127.0.0.1:1/api', const Duration(seconds: 1)), isFalse);
    expect(await isOrwickle('not a url', const Duration(seconds: 1)), isFalse);
  });

  test('network hosts are private addresses and never this device itself', () async {
    final hosts = await networkHosts();
    final own = [
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4))
        for (final a in i.addresses) a.address,
    ];
    for (final host in hosts) {
      expect(own, isNot(contains(host)));
      expect(host, matches(RegExp(r'^(10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.)')));
    }
  });
}
