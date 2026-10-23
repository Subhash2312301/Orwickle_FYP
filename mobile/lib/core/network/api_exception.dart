/// An API failure the UI can show directly.
///
/// The backend always answers errors as { "error": { "code", "message", "details" } },
/// so [code] can be checked in code and [message] shown to the user.
class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.statusCode, this.details});

  final String code;
  final String message;
  final int? statusCode;

  /// For VALIDATION_ERROR: field name → message. For other codes: extra values
  /// such as remainingAttempts or retryAfterSeconds.
  final Map<String, dynamic>? details;

  bool get isNetworkError => code == 'NETWORK_ERROR' || code == 'TIMEOUT';

  /// Field messages from a VALIDATION_ERROR, ready to show under form fields.
  Map<String, String> get fieldErrors => code == 'VALIDATION_ERROR' && details != null
      ? details!.map((field, message) => MapEntry(field, '$message'))
      : const {};

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
