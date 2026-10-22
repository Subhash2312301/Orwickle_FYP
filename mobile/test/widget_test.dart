import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orwickle/core/network/api_client.dart';
import 'package:orwickle/core/network/api_exception.dart';
import 'package:orwickle/features/system_check/health_service.dart';
import 'package:orwickle/features/system_check/system_check_screen.dart';

class _FakeHealthService extends HealthService {
  _FakeHealthService(this._result) : super(ApiClient());

  final Object _result; // HealthStatus or ApiException

  @override
  Future<HealthStatus> check() async {
    final result = _result;
    if (result is ApiException) throw result;
    return result as HealthStatus;
  }
}

Widget _screen(HealthService service) =>
    MaterialApp(home: SystemCheckScreen(service: service));

void main() {
  testWidgets('shows backend and database as connected', (tester) async {
    await tester.pumpWidget(_screen(_FakeHealthService(
      const HealthStatus(serverOk: true, databaseConnected: true, dbLatencyMs: 42),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Backend server'), findsOneWidget);
    expect(find.text('42 ms'), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsNothing);
  });

  testWidgets('shows the error message when the server is unreachable', (tester) async {
    await tester.pumpWidget(_screen(_FakeHealthService(
      const ApiException(code: 'NETWORK_ERROR', message: 'Cannot reach the server.'),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Cannot reach the server.'), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsNWidgets(2));
  });
}
