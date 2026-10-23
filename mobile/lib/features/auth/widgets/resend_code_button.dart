import 'dart:async';

import 'package:flutter/material.dart';

/// "Resend code" link that is disabled during a countdown (60 s by default,
/// or the server's retryAfterSeconds after an OTP_COOLDOWN error).
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({super.key, required this.onResend, this.initialWait = 60});

  /// Sends a new code. Returns the number of seconds to wait before the next resend.
  final Future<int> Function() onResend;
  final int initialWait;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  Timer? _timer;
  int _secondsLeft = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.initialWait);
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) timer.cancel();
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      _startCountdown(await widget.onResend());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_secondsLeft > 0) {
      return TextButton(onPressed: null, child: Text('Resend code in ${_secondsLeft}s'));
    }
    return TextButton(onPressed: _sending ? null : _resend, child: Text(_sending ? 'Sending...' : 'Resend code'));
  }
}
