import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/daos/outbox_dao.dart';
import 'package:sales_sphere_erp/core/db/tables/mutation_outbox_table.dart';
import 'package:sales_sphere_erp/core/sync/mutation_handler.dart';
import 'package:sales_sphere_erp/core/sync/sync_status.dart';
import 'package:sales_sphere_erp/core/utils/app_logger.dart';
import 'package:sales_sphere_erp/core/utils/app_logger_provider.dart';

const int _maxAttempts = 6;
const Duration _baseBackoff = Duration(seconds: 4);

/// Drains the [MutationOutbox], dispatching each pending mutation to the
/// backend via [Dio] and reconciling the response back into local drift
/// tables through registered [MutationHandler]s.
class SyncService {
  SyncService({
    required Dio dio,
    required OutboxDao outbox,
    required AppLogger logger,
    required Map<String, MutationHandler> handlers,
  })  : _dio = dio,
        _outbox = outbox,
        _logger = logger,
        _handlers = handlers;

  final Dio _dio;
  final OutboxDao _outbox;
  final AppLogger _logger;
  final Map<String, MutationHandler> _handlers;

  bool _draining = false;

  /// Drains the outbox FIFO until empty or first non-recoverable error.
  /// Safe to call concurrently — only one drain runs at a time.
  Future<SyncStatus> drain() async {
    if (_draining) {
      return SyncStatus.idle(
        pending: await _pendingCount(),
      );
    }
    _draining = true;
    try {
      var processed = 0;
      while (true) {
        final batch = await _outbox.nextBatch();
        if (batch.isEmpty) break;
        for (final entry in batch) {
          await _processOne(entry);
          processed++;
        }
      }
      _logger.info('Sync drain completed', data: {'processed': processed});
      return SyncStatus.idle(
        pending: await _pendingCount(),
        lastSyncedAt: DateTime.now(),
      );
    } catch (e, st) {
      _logger.error('Sync drain failed', error: e, stackTrace: st);
      return SyncStatus.error(
        e.toString(),
        pending: await _pendingCount(),
      );
    } finally {
      _draining = false;
    }
  }

  Future<void> _processOne(OutboxEntry entry) async {
    await _outbox.markInFlight(entry.id);
    try {
      final response = await _dio.request<dynamic>(
        entry.endpoint,
        data: entry.payloadJson.isEmpty ? null : jsonDecode(entry.payloadJson),
        options: Options(
          method: entry.method,
          headers: <String, String>{
            'Idempotency-Key': entry.idempotencyKey,
          },
        ),
      );
      final handler = _handlers[entry.operation];
      if (handler != null) {
        await handler.onSuccess(
          entry: entry,
          responseBody: response.data,
        );
      }
      await _outbox.markSucceeded(entry.id);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final isClientError = status != null && status >= 400 && status < 500;
      final errorMessage = e.message ?? e.toString();

      // 4xx (except 429) is non-recoverable — dead-letter immediately so
      // we don't retry forever on a malformed payload.
      if (isClientError && status != 429) {
        await _outbox.markDeadLetter(entry.id, errorMessage);
        await _handlers[entry.operation]
            ?.onDeadLetter(entry: entry, error: errorMessage);
        _logger.warn(
          'Outbox entry dead-lettered (client error)',
          data: <String, Object?>{
            'id': entry.id,
            'op': entry.operation,
            'status': status,
          },
        );
        return;
      }

      final attempt = entry.attempts + 1;
      if (attempt >= _maxAttempts) {
        await _outbox.markDeadLetter(entry.id, errorMessage);
        await _handlers[entry.operation]
            ?.onDeadLetter(entry: entry, error: errorMessage);
        _logger.warn(
          'Outbox entry dead-lettered (max attempts)',
          data: <String, Object?>{'id': entry.id, 'attempts': attempt},
        );
      } else {
        final backoff = _baseBackoff * pow(2, attempt - 1).toInt();
        await _outbox.markFailed(
          entry.id,
          errorMessage,
          DateTime.now().add(backoff),
        );
      }
    } catch (e, st) {
      _logger.error(
        'Outbox entry failed unexpectedly',
        error: e,
        stackTrace: st,
        data: <String, Object?>{'id': entry.id, 'op': entry.operation},
      );
      await _outbox.markFailed(
        entry.id,
        e.toString(),
        DateTime.now().add(_baseBackoff),
      );
    }
  }

  Future<int> _pendingCount() async {
    return _outbox.watchPendingCount().first;
  }
}

/// Exposed via a provider so feature modules can register their handlers
/// during their own provider initialisation.
final mutationHandlersProvider =
    Provider<Map<String, MutationHandler>>((_) => <String, MutationHandler>{});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    dio: ref.watch(dioProvider),
    outbox: ref.watch(outboxDaoProvider),
    logger: ref.watch(appLoggerProvider),
    handlers: ref.watch(mutationHandlersProvider),
  );
});
