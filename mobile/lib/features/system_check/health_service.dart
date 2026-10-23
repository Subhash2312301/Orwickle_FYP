import '../../core/network/api_client.dart';

/// Result of GET /api/health.
class HealthStatus {
  const HealthStatus({required this.serverOk, required this.databaseConnected, this.dbLatencyMs});

  factory HealthStatus.fromJson(Map<String, dynamic> json) => HealthStatus(
    serverOk: json['status'] == 'ok',
    databaseConnected: json['database'] == 'connected',
    dbLatencyMs: (json['dbLatencyMs'] as num?)?.toInt(),
  );

  final bool serverOk;
  final bool databaseConnected;
  final int? dbLatencyMs;
}

class HealthService {
  HealthService(this._api);

  final ApiClient _api;

  Future<HealthStatus> check() async => HealthStatus.fromJson(await _api.get('/health'));
}
