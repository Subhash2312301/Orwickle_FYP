import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

/// Single HTTP client for the Orwickle backend.
/// Every failure is converted to an [ApiException], so screens handle one error type.
/// Phase 2 adds the access token and the 15-minute inactivity check here.
class ApiClient {
  ApiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: AppConfig.requestTimeout,
              receiveTimeout: AppConfig.requestTimeout,
              contentType: Headers.jsonContentType,
            ));

  final Dio _dio;

  Future<Map<String, dynamic>> get(String path) => _send(() => _dio.get<dynamic>(path));

  Future<Map<String, dynamic>> post(String path, {Object? body}) =>
      _send(() => _dio.post<dynamic>(path, data: body));

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final error = data['error'] as Map;
      return ApiException(
        code: '${error['code'] ?? 'UNKNOWN'}',
        message: '${error['message'] ?? 'Something went wrong'}',
        statusCode: e.response?.statusCode,
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
