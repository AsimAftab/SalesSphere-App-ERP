import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sales_sphere_erp/core/api/endpoints.dart';
import 'package:sales_sphere_erp/core/api/interceptors/connectivity_interceptor.dart' show ConnectivityInterceptor;
import 'package:sales_sphere_erp/core/auth/token_storage.dart';
import 'package:sales_sphere_erp/features/auth/domain/token_pair.dart';

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

    // The token that just 401'd. Used to detect whether another refresher (a
    // concurrent request, or the background tracking isolate) has already
    // rotated it — which matters because the tracking service refreshes
    // independently while a session is live.
    final staleAuth = err.requestOptions.headers['Authorization'];

    // Coalesce concurrent refreshes — only the first hits the server.
    final pending = _refreshCompleter;
    if (pending != null) {
      await pending.future.catchError((_) {});
    } else {
      final current = await _tokens.readAccessToken();
      final currentAuth =
          (current != null && current.isNotEmpty) ? 'Bearer $current' : null;
      // Only refresh if the stored token is still the one that failed. If it
      // already changed, another isolate rotated it — fall straight through to
      // retry with the fresh token instead of refreshing (and rotating) again.
      if (currentAuth == null || currentAuth == staleAuth) {
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
          // Re-read before clearing: the tracking isolate may have rotated the
          // token with a fresher refresh-token while ours was already stale.
          // Only force logout if nothing newer landed — otherwise a refresh
          // race would log the user out mid-session.
          final latest = await _tokens.readAccessToken();
          final latestAuth = (latest != null && latest.isNotEmpty)
              ? 'Bearer $latest'
              : null;
          if (latestAuth == null || latestAuth == staleAuth) {
            await _tokens.clear();
            _onRefreshFailed();
          }
        } finally {
          _refreshCompleter = null;
        }
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
