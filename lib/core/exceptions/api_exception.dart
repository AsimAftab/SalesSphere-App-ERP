/// Base class for all errors surfaced from the API/network layer.
sealed class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => '$runtimeType($statusCode): $message';
}

class OfflineException extends ApiException {
  const OfflineException([
    super.message = 'No internet connection.',
  ]);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([
    super.message = 'Session expired. Please log in again.',
  ]) : super(statusCode: 401);
}

/// Specialisation thrown by the auth repository on login-time 401s, so UI
/// code can disambiguate "wrong email/password" from "session expired".
class BadCredentialsException extends UnauthorizedException {
  const BadCredentialsException([
    super.message = 'Invalid email or password.',
  ]);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'You do not have permission to do that.',
  ]) : super(statusCode: 403);
}

class NotFoundException extends ApiException {
  const NotFoundException([
    super.message = 'Resource not found.',
  ]) : super(statusCode: 404);
}

class ValidationException extends ApiException {
  const ValidationException(
    super.message, {
    this.fieldErrors = const <String, String>{},
  }) : super(statusCode: 422);

  final Map<String, String> fieldErrors;
}

class ServerException extends ApiException {
  const ServerException([
    String message = 'Something went wrong on our end.',
    int statusCode = 500,
  ]) : super(message, statusCode: statusCode);
}

class NetworkException extends ApiException {
  const NetworkException(super.message, {super.statusCode, super.cause});
}

/// Extracts the human-readable message the backend tucked into a
/// non-2xx envelope:
///
/// ```
/// { "success": false, "error": { "message": "...", "code": "..." } }
/// ```
///
/// Returns `null` when the response body doesn't carry one — call
/// sites should fall back to a generic copy in that case. Lives next
/// to the exception hierarchy because every error UI surface needs
/// it eventually.
String? extractBackendErrorMessage(Object? error) {
  // Cheap import-free duck-type — avoids dragging dio into this file's
  // import graph just to read `.response.data`.
  final dynamic err = error;
  final dynamic data = err?.response?.data;
  if (data is Map<String, dynamic>) {
    final dynamic inner = data['error'];
    if (inner is Map<String, dynamic>) {
      final dynamic message = inner['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    final dynamic topLevel = data['message'];
    if (topLevel is String && topLevel.isNotEmpty) return topLevel;
  }
  return null;
}
