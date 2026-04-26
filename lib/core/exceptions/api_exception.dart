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
