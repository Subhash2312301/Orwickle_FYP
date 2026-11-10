// Web build: no network scanning in the browser.

Future<bool> isOrwickle(String apiUrl, Duration timeout) async => false;

Future<List<String>> networkHosts() async => const [];
