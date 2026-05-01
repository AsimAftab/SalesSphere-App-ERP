import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';

/// Maps an arbitrary error (typically from `AsyncValue.error`) into a
/// user-facing message. Pattern-matches on the typed [ApiException]
/// hierarchy — the error interceptor + repositories are responsible for
/// throwing the right subtype, so callers never have to sniff strings.
String userMessageFor(
  Object? err, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  return switch (err) {
    // More specific subtypes must come before their parents.
    BadCredentialsException() =>
      'Invalid email or password. Please try again.',
    UnauthorizedException() => 'Session expired. Please log in again.',
    OfflineException() => 'No internet connection.',
    NetworkException() => 'Connection error. Please check your internet.',
    ForbiddenException() => 'You do not have permission to do that.',
    NotFoundException() => 'Not found.',
    ValidationException(:final message) => message,
    ServerException() => 'Server error. Please try again later.',
    _ => fallback,
  };
}
