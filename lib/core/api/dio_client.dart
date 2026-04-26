import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'package:sales_sphere_erp/core/api/interceptors/auth_interceptor.dart';
import 'package:sales_sphere_erp/core/api/interceptors/connectivity_interceptor.dart';
import 'package:sales_sphere_erp/core/api/interceptors/error_interceptor.dart';
import 'package:sales_sphere_erp/core/api/interceptors/logging_interceptor.dart';
import 'package:sales_sphere_erp/core/auth/token_storage.dart';
import 'package:sales_sphere_erp/core/config/env.dart';
import 'package:sales_sphere_erp/core/utils/app_logger_provider.dart';

export 'package:sales_sphere_erp/core/api/endpoints.dart';

final connectivityProvider = Provider<Connectivity>((_) => Connectivity());

/// Refresh handler — implemented properly by AuthController. Until that lands,
/// returning null causes the auth interceptor to clear tokens and log out.
final tokenRefreshHandlerProvider =
    Provider<Future<TokenPair?> Function(String refreshToken)>((ref) {
  return (refreshToken) async => null;
});

final tokenRefreshFailureSinkProvider =
    Provider<void Function()>((ref) => () {});

final dioProvider = Provider<Dio>((ref) {
  final env = Env.current;
  final logger = ref.watch(appLoggerProvider);
  final tokens = ref.watch(tokenStorageProvider);
  final connectivity = ref.watch(connectivityProvider);
  final refreshHandler = ref.watch(tokenRefreshHandlerProvider);
  final onRefreshFailed = ref.watch(tokenRefreshFailureSinkProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  // Order matters: connectivity → auth → pretty-logger → app-logger → error.
  dio.interceptors.addAll(<Interceptor>[
    ConnectivityInterceptor(connectivity),
    AuthInterceptor(
      dio: dio,
      tokenStorage: tokens,
      refreshHandler: refreshHandler,
      onRefreshFailed: onRefreshFailed,
    ),
    if (kDebugMode)
      PrettyDioLogger(
        requestHeader: false,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        compact: true,
      ),
    LoggingInterceptor(logger),
    const ErrorInterceptor(),
  ]);

  ref.onDispose(dio.close);
  return dio;
});

/// Convenience that exposes the configured base URL, useful for code that
/// doesn't need the full Dio instance (e.g. socket.io connections).
final apiBaseUrlProvider = Provider<String>((_) => Env.current.apiBaseUrl);

