import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Thin wrapper around `package:logger` that adds structured-data fields and a
/// stable interface, so the rest of the app never imports the logger package
/// directly. Sentry breadcrumb forwarding can hook in here later.
class AppLogger {
  AppLogger({Logger? logger})
      : _logger = logger ??
            Logger(
              level: kReleaseMode ? Level.warning : Level.debug,
              printer: PrettyPrinter(
                methodCount: 0,
                errorMethodCount: 6,
                lineLength: 100,
                printEmojis: false,
                dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
              ),
            );

  final Logger _logger;

  void debug(String message, {Map<String, Object?>? data}) {
    _logger.d(_format(message, data));
  }

  void info(String message, {Map<String, Object?>? data}) {
    _logger.i(_format(message, data));
  }

  void warn(
    String message, {
    Map<String, Object?>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.w(
      _format(message, data),
      error: error,
      stackTrace: stackTrace,
    );
  }

  void error(
    String message, {
    Map<String, Object?>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.e(
      _format(message, data),
      error: error,
      stackTrace: stackTrace,
    );
  }

  String _format(String message, Map<String, Object?>? data) {
    if (data == null || data.isEmpty) return message;
    final pairs = data.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}=${e.value}')
        .join(' ');
    return pairs.isEmpty ? message : '$message  ‹$pairs›';
  }
}
