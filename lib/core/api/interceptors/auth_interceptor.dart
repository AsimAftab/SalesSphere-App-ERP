import 'dart:async';

import 'package:dio/dio.dart';

import '../../auth/token_storage.dart';
import '../endpoints.dart';

/// Attaches the access token to every outgoing request. On 401, it attempts a
/// single refresh-and-retry; on refresh failure it propagates the original
/// 401 and clears stored tokens (the auth controller observes that and
/// transitions the app to the login screen).
///
/// Must run AFTER [ConnectivityInterceptor] (no point refreshing offline) and
/// BEFORE the logging interceptor.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required TokenStorage tokenStorage,
    required Future<TokenPair?> Function(String refreshToken) refreshHandler,
    required void Function() onRefreshFailed,
  })  : _dio = dio,
        _tokens = tokenStorage,
        _refreshHandler = refreshHandler,
        _onRefreshFailed = onRefreshFailed;

  final Dio _dio;
  final TokenStorage _tokens;
  final Future<TokenPair?> Function(String refreshToken) _refreshHandler;
  final void Function() _onRefreshFailed;

  Completer<void>? _refreshCompleter;

  static const _retriedFlag = '__ss_auth_retried__';
  static const _skipAuthFlag = '__ss_skip_auth__';

  /// Endpoints that should never have the access token attached.
  static const _publicEndpoints = <String>{
    Endpoints.login,
    Endpoints.refresh,
  };

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[_skipAuthFlag] == true ||
        _publicEndpoints.contains(options.path)) {
      return handler.next(options);
    }

    final token = await _tokens.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra[_retriedFlag] == true;
    final isRefreshCall = err.requestOptions.path == Endpoints.refresh;

    if (!isUnauthorized || alreadyRetried || isRefreshCall) {
      return handler.next(err);
    }

    // Coalesce concurrent refreshes — only the first hits the server.
    final pending = _refreshCompleter;
    if (pending != null) {
      await pending.future.catchError((_) {});
    } else {
      final completer = Completer<void>();
      _refreshCompleter = completer;
      try {
        final refreshToken = await _tokens.readRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          throw StateError('No refresh token');
        }
        final pair = await _refreshHandler(refreshToken);
        if (pair == null) throw StateError('Refresh handler returned null');
        await _tokens.save(
          accessToken: pair.accessToken,
          refreshToken: pair.refreshToken,
          expiresAt: pair.expiresAt,
        );
        completer.complete();
      } catch (e) {
        completer.completeError(e);
        await _tokens.clear();
        _onRefreshFailed();
      } finally {
        _refreshCompleter = null;
      }
    }

    // If refresh failed, surface the original 401.
    final newToken = await _tokens.readAccessToken();
    if (newToken == null || newToken.isEmpty) {
      return handler.next(err);
    }

    // Retry the original request with the new token.
    final retryOptions = err.requestOptions
      ..extra[_retriedFlag] = true
      ..headers['Authorization'] = 'Bearer $newToken';
    try {
      final response = await _dio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;
}

/// Marks an outgoing request to skip authentication entirely.
/// Use sparingly — most public endpoints are listed in
/// [AuthInterceptor._publicEndpoints] already.
extension SkipAuthOptions on Options {
  Options skipAuth() => copyWith(
        extra: <String, dynamic>{
          ...?extra,
          AuthInterceptor._skipAuthFlag: true,
        },
      );
}
