import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../../exceptions/api_exception.dart';

/// Short-circuits requests when the device has no network connectivity, so we
/// don't waste time hitting Dio's connect-timeout. Must run BEFORE the auth
/// and logging interceptors.
class ConnectivityInterceptor extends Interceptor {
  ConnectivityInterceptor(this._connectivity);

  final Connectivity _connectivity;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final results = await _connectivity.checkConnectivity();
    final hasNetwork =
        results.any((r) => r != ConnectivityResult.none);

    if (!hasNetwork) {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const OfflineException(),
          message: 'No network connectivity',
        ),
      );
    }
    handler.next(options);
  }
}
