import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import 'health_service.dart';

/// Phase 1 end-to-end check: app → Node.js backend → Supabase PostgreSQL.
/// Replaced by the splash/login flow in Phase 2.
class SystemCheckScreen extends StatefulWidget {
  const SystemCheckScreen({super.key, this.service});

  /// Injected in tests; the real backend is used otherwise.
  final HealthService? service;

  @override
  State<SystemCheckScreen> createState() => _SystemCheckScreenState();
}

class _SystemCheckScreenState extends State<SystemCheckScreen> {
  late final HealthService _service = widget.service ?? HealthService(ApiClient());

  bool _loading = true;
  HealthStatus? _status;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await _service.check();
      if (mounted) setState(() => _status = status);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status;
    final serverOk = _error == null && (status?.serverOk ?? false);
    final dbOk = _error == null && (status?.databaseConnected ?? false);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(Icons.storefront_rounded, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Orwickle', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
              Text('System check', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 40),
              _StatusTile(label: 'Mobile app', ok: true, loading: false),
              _StatusTile(label: 'Backend server', ok: serverOk, loading: _loading),
              _StatusTile(
                label: 'Database',
                ok: dbOk,
                loading: _loading,
                detail: dbOk && status?.dbLatencyMs != null ? '${status!.dbLatencyMs} ms' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const Spacer(),
              Text(AppConfig.apiBaseUrl, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _check,
                icon: const Icon(Icons.refresh),
                label: const Text('Check again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.label, required this.ok, required this.loading, this.detail});

  final String label;
  final bool ok;
  final bool loading;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final Widget leading = loading
        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
        : Icon(ok ? Icons.check_circle : Icons.cancel, color: ok ? StatusColors.of(context).success : colors.error);
    return Card(
      child: ListTile(
        leading: leading,
        title: Text(label),
        trailing: Text(loading ? '' : (detail ?? (ok ? 'Connected' : 'Not reachable'))),
      ),
    );
  }
}
