import 'package:flutter/material.dart';

import '../../core/config/server_address.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../system_check/health_service.dart';

/// Lets one APK reach the laptop backend on whatever Wi-Fi or hotspot both devices share.
/// Opened by long-pressing the logo on the auth screens.
Future<void> showServerAddressSheet(BuildContext context) => showAppBottomSheet<void>(
  context,
  title: 'Server address',
  subtitle: "Your laptop's IP on the Wi-Fi or hotspot the phone is using. Run ipconfig on the laptop to find it.",
  builder: (context) => const _ServerAddressForm(),
);

class _ServerAddressForm extends StatefulWidget {
  const _ServerAddressForm();

  @override
  State<_ServerAddressForm> createState() => _ServerAddressFormState();
}

class _ServerAddressFormState extends State<_ServerAddressForm> {
  final _form = GlobalKey<FormState>();
  late final _address = TextEditingController(text: ServerAddress.display);

  bool _testing = false;
  String? _result;
  bool _ok = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    if (!_form.currentState!.validate()) return;
    final url = ServerAddress.normalize(_address.text)!;
    setState(() {
      _testing = true;
      _result = null;
    });
    try {
      final status = await HealthService(ApiClient(baseUrl: url)).check();
      await ServerAddress.save(url);
      _ok = status.serverOk;
      _result = status.databaseConnected
          ? 'Connected and saved.'
          : 'Saved. The server answered, but its database is not connected.';
    } on ApiException catch (e) {
      _ok = false;
      _result = 'Could not reach $url. ${e.message}';
    } finally {
      if (mounted) setState(() => _testing = false);
    }
    if (_ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _address,
          label: 'Laptop IP address',
          hint: '192.168.43.5',
          helper: 'Port 4000 is added for you.',
          icon: Icons.lan_outlined,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _testAndSave(),
          validator: (v) => ServerAddress.normalize(v ?? '') == null ? 'Enter an IP like 192.168.43.5' : null,
        ),
        const SizedBox(height: Gaps.lg),
        if (_result != null)
          AppBanner(
            message: _result!,
            icon: _ok ? Icons.check_circle_outline : Icons.error_outline,
            role: _ok ? ToneRole.approved : ToneRole.rejected,
          ),
        AppButton(label: 'Test and save', icon: Icons.wifi_tethering, loading: _testing, onPressed: _testAndSave),
        const SizedBox(height: Gaps.sm),
        AppButton.ghost(
          label: 'Use default',
          onPressed: _testing
              ? null
              : () async {
                  await ServerAddress.reset();
                  if (context.mounted) Navigator.of(context).pop();
                },
        ),
      ],
    ),
  );
}
