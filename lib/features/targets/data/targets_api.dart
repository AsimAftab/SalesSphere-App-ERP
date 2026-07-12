import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/collection/data/dto/wire_codecs.dart';
import 'package:sales_sphere_erp/features/targets/data/dto/my_target_dto.dart';
import 'package:sales_sphere_erp/features/targets/data/dto/target_transaction_dto.dart';
import 'package:sales_sphere_erp/features/targets/data/dto/targets_drill_down_page_dto.dart';

/// HTTP layer for the Targets feature.
///
/// Both endpoints are **read-only** — targets are created and assigned by an
/// admin on web, so there is no write path, no outbox handler and no
/// `clientRequestId`. Auth rides the existing interceptor chain.
///
/// Every GET query is `.strict()` server-side: one unknown param is a hard
/// 4xx, not a silent ignore. Only send what the schema declares.
class TargetsApi {
  TargetsApi(this._dio);

  final Dio _dio;

  /// `GET /targets/me` — the rep's own targets for a day, with live progress.
  ///
  /// [date] == null sends no param at all: the server resolves "today" in the
  /// **org's** timezone, which the device can't compute. DAILY targets are
  /// scored for that day, MONTHLY for the month containing it. The response
  /// is a bare array — a rep holds a handful of targets, nothing to paginate.
  Future<List<MyTargetDto>> myTargets({DateTime? date}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.targetsMe,
      queryParameters: <String, dynamic>{
        if (date != null) 'date': dateToWire(date),
      },
    );
    return _unwrapList(response.data)
        .map((j) => MyTargetDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `GET /targets/drill-down` — the records behind one achieved number,
  /// cursor-paginated.
  ///
  /// Deliberately no `employeeId`: a rep is pinned to themselves server-side
  /// regardless of what they send, so there is nothing to pass and nothing to
  /// leak. [periodStart] / [periodEnd] come straight off the tapped
  /// `/targets/me` row and are **inclusive** at both ends. [cursor] is
  /// opaque — pass `nextCursor` back verbatim, never parse it.
  Future<TargetsDrillDownPageDto> drillDown({
    required String metric,
    required DateTime periodStart,
    required DateTime periodEnd,
    int limit = 50,
    String? cursor,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.targetsDrillDown,
      queryParameters: <String, dynamic>{
        'metric': metric,
        'periodStart': dateToWire(periodStart),
        'periodEnd': dateToWire(periodEnd),
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );
    return _pageFrom(_unwrapMap(response.data));
  }

  // ── Envelope helpers ──────────────────────────────────────────────────────
  // Mirrors `collection_api.dart`. Duplicated per-feature by house convention
  // so the FormatException copy names the feature that failed.

  TargetsDrillDownPageDto _pageFrom(Map<String, dynamic> data) {
    final rawItems = data['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Malformed targets drill-down page: missing or invalid `items` array',
      );
    }
    final items = rawItems
        .map((j) => TargetTransactionDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
    final hasMore = (data['hasMore'] as bool?) ?? false;
    final nextCursor = hasMore ? data['nextCursor'] as String? : null;
    return TargetsDrillDownPageDto(items: items, nextCursor: nextCursor);
  }

  Map<String, dynamic> _unwrapMap(Map<String, dynamic>? body) {
    final inner = _unwrapData(body);
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed targets envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }

  List<dynamic> _unwrapList(Map<String, dynamic>? body) {
    final inner = _unwrapData(body);
    if (inner is! List<dynamic>) {
      throw const FormatException(
        'Malformed targets envelope: missing or invalid `data` array',
      );
    }
    return inner;
  }

  Object? _unwrapData(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty targets response body');
    }
    // Require `success` to be explicitly `true`. A missing / null / non-bool
    // flag must NOT slip past — that's a malformed envelope.
    final success = body['success'];
    if (success is! bool || !success) {
      throw const FormatException(
        'Malformed targets envelope: invalid `success` flag',
      );
    }
    return body['data'];
  }
}

final targetsApiProvider = Provider<TargetsApi>(
  (ref) => TargetsApi(ref.watch(dioProvider)),
);
