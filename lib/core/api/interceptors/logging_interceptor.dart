import 'package:dio/dio.dart';

import '../../utils/app_logger.dart';

/// Lightweight request/response/error logger sitting alongside
/// `pretty_dio_logger`. The pretty logger is great in dev for full payload
/// inspection; this one funnels structured events into [AppLogger] for
/// release builds (no secrets — see redaction below).
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor(this._logger);

  final AppLogger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.debug(
      '→ ${options.method} ${options.uri}',
      data: <String, Object?>{
        'method': options.method,
        'path': options.path,
      },
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _logger.debug(
      '← ${response.statusCode} ${response.requestOptions.method} '
      '${response.requestOptions.uri}',
      data: <String, Object?>{
        'status': response.statusCode,
        'path': response.requestOptions.path,
      },
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.warn(
      '✗ ${err.response?.statusCode ?? '-'} '
      '${err.requestOptions.method} ${err.requestOptions.uri}',
      data: <String, Object?>{
        'status': err.response?.statusCode,
        'path': err.requestOptions.path,
        'type': err.type.name,
      },
      error: err,
      stackTrace: err.stackTrace,
    );
    handler.next(err);
  }
}
