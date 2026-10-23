import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

/// Returns a valid access token, refreshing the session first when needed.
/// Returns null when the user is not logged in.
typedef AccessTokenProvider = Future<String?> Function({bool forceRefresh});

/// Single HTTP client for the Orwickle backend.
/// Every failure is converted to an [ApiException], so screens handle one error type.
/// Requests with `auth: true` carry the access token; on a 401 the session is refreshed once and retried.
class ApiClient {
  ApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: AppConfig.requestTimeout,
              receiveTimeout: AppConfig.requestTimeout,
              contentType: Headers.jsonContentType,
            ),
          );

  final Dio _dio;

  /// Set by the session controller once it exists.
  AccessTokenProvider? accessTokenProvider;

  Future<Map<String, dynamic>> get(String path, {bool auth = false}) =>
      _send(auth, (options) => _dio.get<dynamic>(path, options: options));

  Future<Map<String, dynamic>> post(String path, {Object? body, bool auth = false}) =>
      _send(auth, (options) => _dio.post<dynamic>(path, data: body, options: options));

  Future<Map<String, dynamic>> put(String path, {Object? body, bool auth = false}) =>
      _send(auth, (options) => _dio.put<dynamic>(path, data: body, options: options));

  Future<Map<String, dynamic>> delete(String path, {bool auth = false}) =>
      _send(auth, (options) => _dio.delete<dynamic>(path, options: options));

  /// Uploads one image file as multipart field "image" (PUT).
  Future<Map<String, dynamic>> uploadImage(String path, String filePath, {bool auth = true}) => _send(
    auth,
    // a fresh FormData per attempt, because a sent one cannot be sent again on retry
    (options) async => _dio.put<dynamic>(
      path,
      data: FormData.fromMap({'image': await MultipartFile.fromFile(filePath)}),
      options: options,
    ),
  );

  Future<Map<String, dynamic>> _send(bool auth, Future<Response<dynamic>> Function(Options options) request) async {
    try {
      return _body(await request(await _options(auth)));
    } on DioException catch (e) {
      if (auth && e.response?.statusCode == 401) {
        try {
          return _body(await request(await _options(auth, forceRefresh: true)));
        } on DioException catch (retry) {
          throw _toApiException(retry);
        }
      }
      throw _toApiException(e);
    }
  }

  Future<Options> _options(bool auth, {bool forceRefresh = false}) async {
    if (!auth) return Options();
    final token = await accessTokenProvider?.call(forceRefresh: forceRefresh);
    if (token == null) {
      throw const ApiException(code: 'SESSION_EXPIRED', message: 'Please log in again.');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // 204 responses have no body
  Map<String, dynamic> _body(Response<dynamic> response) =>
      response.data is Map ? Map<String, dynamic>.from(response.data as Map) : <String, dynamic>{};

  ApiException _toApiException(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final error = data['error'] as Map;
      final details = error['details'];
      return ApiException(
        code: '${error['code'] ?? 'UNKNOWN'}',
        message: '${error['message'] ?? 'Something went wrong'}',
        statusCode: e.response?.statusCode,
        details: details is Map ? Map<String, dynamic>.from(details) : null,
      );
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const ApiException(code: 'TIMEOUT', message: 'The server took too long to respond.');
      case DioExceptionType.connectionError:
        return const ApiException(
          code: 'NETWORK_ERROR',
          message: 'Cannot reach the server. Check your internet connection.',
        );
      default:
        return ApiException(
          code: 'UNKNOWN',
          message: 'Something went wrong. Please try again.',
          statusCode: e.response?.statusCode,
        );
    }
  }
}
