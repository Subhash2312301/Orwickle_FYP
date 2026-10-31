import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import 'app_button.dart';
import 'chips.dart';
import 'empty_state.dart';

/// A failed load, with a retry button. No connection gets its own picture and wording.
///
///     ErrorState.from(snapshot.error, onRetry: _reload)
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry, this.offline = false, this.title});

  /// Builds the right message from whatever was thrown (an [ApiException] or anything else).
  factory ErrorState.from(Object? error, {Key? key, VoidCallback? onRetry, String? fallback}) {
    final api = error is ApiException ? error : null;
    return ErrorState(
      key: key,
      offline: api?.isNetworkError ?? false,
      message: api?.message ?? fallback ?? 'Something went wrong. Please try again.',
      onRetry: onRetry,
    );
  }

  final String message;
  final VoidCallback? onRetry;
  final bool offline;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      role: offline ? ToneRole.neutral : ToneRole.rejected,
      title: title ?? (offline ? 'You are offline' : 'Something went wrong'),
      message: message,
      action: onRetry == null
          ? null
          : AppButton.secondary(label: 'Try again', icon: Icons.refresh, expand: false, onPressed: onRetry),
    );
  }
}
