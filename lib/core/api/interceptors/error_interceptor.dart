import 'package:dio/dio.dart';

import '../../exceptions/api_exception.dart';

/// Maps Dio exceptions into the app's [ApiException] hierarchy so feature
/// code never has to inspect [DioException] directly. Always the LAST
/// interceptor in the chain.
class ErrorInterceptor extends Interceptor {
  const ErrorInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final mapped = _map(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: mapped,
        message: mapped.message,
        stackTrace: err.stackTrace,
      ),
    );
  }

  ApiException _map(DioException err) {
    if (err.error is ApiException) return err.error! as ApiException;

    final status = err.response?.statusCode;
    final responseMessage = _extractMessage(err.response?.data);

    switch (status) {
      case 401:
        return UnauthorizedException(
          responseMessage ?? 'Session expired. Please log in again.',
        );
      case 403:
        return ForbiddenException(
          responseMessage ?? 'You do not have permission to do that.',
        );
      case 404:
        return NotFoundException(responseMessage ?? 'Resource not found.');
      case 422:
        return ValidationException(
          responseMessage ?? 'Invalid request.',
          fieldErrors: _extractFieldErrors(err.response?.data),
        );
    }

    if (status != null && status >= 500) {
      return ServerException(
        responseMessage ?? 'Something went wrong on our end.',
        status,
      );
    }

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return NetworkException(
        responseMessage ?? 'Network is unstable. Please try again.',
        statusCode: status,
        cause: err,
      );
    }

    return NetworkException(
      responseMessage ?? err.message ?? 'Unexpected network error.',
      statusCode: status,
      cause: err,
    );
  }

  String? _extractMessage(Object? body) {
    if (body is Map<String, dynamic>) {
      final m = body['message'] ?? body['error'] ?? body['detail'];
      if (m is String && m.isNotEmpty) return m;
    }
    return null;
  }

  Map<String, String> _extractFieldErrors(Object? body) {
    if (body is Map<String, dynamic>) {
      final raw = body['errors'] ?? body['fieldErrors'];
      if (raw is Map) {
        return raw.map(
          (key, value) => MapEntry('$key', '$value'),
        );
      }
    }
    return const <String, String>{};
  }
}
