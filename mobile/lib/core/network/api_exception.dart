/// An API failure the UI can show directly.
///
/// The backend always answers errors as { "error": { "code", "message" } },
/// so [code] can be checked in code and [message] shown to the user.
class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  bool get isNetworkError => code == 'NETWORK_ERROR' || code == 'TIMEOUT';

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
