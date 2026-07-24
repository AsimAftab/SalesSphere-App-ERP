import 'package:dio/dio.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';

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
      case 400:
        // Surface the backend's human message (e.g. attendance window /
        // weekly-off rejections) instead of letting a 400 fall through to a
        // generic NetworkException copy. Treated like a validation failure.
        return ValidationException(
          responseMessage ?? 'Invalid request.',
          fieldErrors: _extractFieldErrors(err.response?.data),
          statusCode: 400,
        );
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

  /// Pulls the most useful human message out of an error body.
  ///
  /// The backend's shape is `{success: false, error: {message, code, status,
  /// details?}}` — note `error` is an **object**, not a string, so a naive
  /// `body['error'] as String` misses it entirely and every caller falls back
  /// to generic copy.
  ///
  /// For a Zod failure `error.message` is always the literal
  /// `"Validation failed"` and the field-specific copy lives in
  /// `error.details[].message`. Prefer the first detail — "Amount must be
  /// greater than 0." beats "Validation failed" on every surface that renders
  /// this.
  String? _extractMessage(Object? body) {
    if (body is! Map<String, dynamic>) return null;

    final inner = body['error'];
    if (inner is Map<String, dynamic>) {
      final detail = _firstDetailMessage(inner['details']);
      if (detail != null) return detail;
      final m = inner['message'];
      if (m is String && m.isNotEmpty) return m;
    }

    // Flat shapes: `{message: ...}` / `{error: "..."}` / `{detail: ...}`.
    final flat = body['message'] ?? inner ?? body['detail'];
    if (flat is String && flat.isNotEmpty) return flat;
    return null;
  }

  /// Field-keyed validation copy for form surfaces.
  ///
  /// Reads the backend's `error.details` array (`[{path, message, code}]`),
  /// falling back to the flat `errors` / `fieldErrors` map some endpoints use.
  Map<String, String> _extractFieldErrors(Object? body) {
    if (body is! Map<String, dynamic>) return const <String, String>{};

    final inner = body['error'];
    if (inner is Map<String, dynamic>) {
      final details = inner['details'];
      if (details is List) {
        final out = <String, String>{};
        for (final d in details) {
          if (d is! Map) continue;
          final path = _detailPath(d['path']);
          final message = d['message'];
          if (path == null || message is! String || message.isEmpty) continue;
          // First message per field wins — Zod can emit several per path and
          // the form only has room for one.
          out.putIfAbsent(path, () => message);
        }
        if (out.isNotEmpty) return out;
      }
    }

    final raw = body['errors'] ?? body['fieldErrors'];
    if (raw is Map) {
      return raw.map((key, value) => MapEntry('$key', '$value'));
    }
    return const <String, String>{};
  }

  String? _firstDetailMessage(Object? details) {
    if (details is! List || details.isEmpty) return null;
    for (final d in details) {
      if (d is! Map) continue;
      final message = d['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return null;
  }

  /// A Zod issue path is usually already joined (`"amount"`), but a nested
  /// issue can arrive as a list (`["invoiceIds", 0]`). Normalise both.
  String? _detailPath(Object? path) {
    if (path is String && path.isNotEmpty) return path;
    if (path is List && path.isNotEmpty) return path.join('.');
    return null;
  }
}
