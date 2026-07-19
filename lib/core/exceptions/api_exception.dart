import 'package:sales_sphere_erp/core/utils/geo_distance.dart';

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
    int statusCode = 422,
  }) : super(statusCode: statusCode);

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

/// `502 UPLOAD_FAILED`: the backend's media store (Cloudinary) rejected or
/// timed out on a file upload. Transient and retryable — the UI should keep
/// the form open and invite a retry rather than showing a generic error.
class UploadFailedException extends ApiException {
  const UploadFailedException([
    String message = 'Photo upload failed. Check your connection and retry.',
  ]) : super(message, statusCode: 502);
}

/// Client-side gate: the device couldn't obtain a location fix, so an
/// action that requires coordinates (attendance check-in/out) can't run.
/// Not an HTTP error — thrown before any request leaves the app.
class LocationUnavailableException extends ApiException {
  const LocationUnavailableException([
    super.message =
        'Location is required. Enable location access and try again.',
  ]);
}

/// Client-side geofence gate: the user is farther than [radiusMeters] from
/// the configured office anchor, so attendance check-in/out is refused.
/// The server doesn't enforce this — the app does.
class OutsideGeofenceException extends ApiException {
  OutsideGeofenceException({
    required this.distanceMeters,
    required this.radiusMeters,
  }) : super(
          "You're ${formatDistanceMeters(distanceMeters)} away. Move within "
          '${radiusMeters.round()} m of the office and try again.',
        );

  final double distanceMeters;
  final double radiusMeters;
}

/// Extracts the human-readable message the backend tucked into a
/// non-2xx envelope:
///
/// ```
/// { "success": false, "error": { "message": "...", "code": "...",
///                                "details": [{ "path": "...", "message": "..." }] } }
/// ```
///
/// Returns `null` when the response body doesn't carry one — call
/// sites should fall back to a generic copy in that case. Lives next
/// to the exception hierarchy because every error UI surface needs
/// it eventually.
///
/// Precedence must stay in lockstep with `ErrorInterceptor._extractMessage`:
/// a Zod failure always sets `error.message` to the literal
/// `"Validation failed"` and puts the useful copy in `error.details`, so the
/// first detail wins. Repositories compare this against the mapped
/// exception's message and overwrite on mismatch — if the two disagreed,
/// the specific message would be clobbered by the generic one.
/// Extracts the machine-readable `error.code` (e.g.
/// `CREDIT_LIMIT_EXCEEDED`) from the same envelope as
/// [extractBackendErrorMessage], so call sites can branch on a stable
/// identifier instead of matching human copy.
String? extractBackendErrorCode(Object? error) {
  try {
    // Same import-free duck-type as extractBackendErrorMessage.
    final dynamic err = error;
    final dynamic data = err?.response?.data;
    if (data is Map<String, dynamic>) {
      final dynamic inner = data['error'];
      if (inner is Map<String, dynamic>) {
        final dynamic code = inner['code'];
        if (code is String && code.isNotEmpty) return code;
      }
    }
    // Not a Dio-shaped error — nothing to read. Call sites pass whatever
    // a catch-all `on Object` handed them, so this must not throw.
    // ignore: avoid_catching_errors
  } on NoSuchMethodError {}
  return null;
}

String? extractBackendErrorMessage(Object? error) {
  // Cheap import-free duck-type — avoids dragging dio into this file's
  // import graph just to read `.response.data`.
  final dynamic err = error;
  final dynamic data = err?.response?.data;
  if (data is Map<String, dynamic>) {
    final dynamic inner = data['error'];
    if (inner is Map<String, dynamic>) {
      final dynamic details = inner['details'];
      if (details is List) {
        for (final dynamic d in details) {
          if (d is! Map) continue;
          final dynamic message = d['message'];
          if (message is String && message.isNotEmpty) return message;
        }
      }
      final dynamic message = inner['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    final dynamic topLevel = data['message'];
    if (topLevel is String && topLevel.isNotEmpty) return topLevel;
  }
  return null;
}
