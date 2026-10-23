import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import '../widgets/form_widgets.dart';

/// Sends a new OTP and returns how many seconds to wait before the next one.
Future<int> resendCode(BuildContext context, AuthApi api, String email, OtpPurpose purpose) async {
  try {
    await api.resendOtp(email: email, purpose: purpose);
    if (context.mounted) showInfoSnack(context, 'A new code has been sent to $email');
    return 60;
  } on ApiException catch (e) {
    if (e.code == 'OTP_COOLDOWN') return (e.details?['retryAfterSeconds'] as num?)?.toInt() ?? 60;
    if (context.mounted) showErrorSnack(context, e);
    return 0;
  }
}

String locationWithEmail(String path, String email) =>
    Uri(path: path, queryParameters: {'email': email}).toString();
