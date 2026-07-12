import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/daos/targets_dao.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/collection/data/dto/wire_codecs.dart';
import 'package:sales_sphere_erp/features/targets/data/dto/my_target_dto.dart';
import 'package:sales_sphere_erp/features/targets/data/dto/target_transaction_dto.dart';
import 'package:sales_sphere_erp/features/targets/data/targets_api.dart';
import 'package:sales_sphere_erp/features/targets/domain/repositories/targets_repository.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_drill_down_record.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_enums.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';

/// Network-first repository for the read-only Targets feature.
///
/// Achievement is computed live on every server read — there is no cached
/// `achieved` column anywhere, and numbers can go *down* (a cancelled order
/// removes progress). So the drift cache is strictly an offline fallback:
/// always refetch while online, serve last-synced rows only when the network
/// is unreachable.
class TargetsRepositoryImpl implements TargetsRepository {
  TargetsRepositoryImpl({required TargetsApi api, required TargetsDao dao})
      : _api = api,
        _dao = dao;

  final TargetsApi _api;
  final TargetsDao _dao;

  @override
  Future<MyTargetsSnapshot> getMyTargets({DateTime? date}) async {
    final dateKey = date == null ? '' : dateToWire(date);
    try {
      final dtos = await _api.myTargets(date: date);
      await _dao.replaceForDateKey(
        dateKey,
        dtos.map((d) => _companion(dateKey, d)).toList(growable: false),
      );
      return MyTargetsSnapshot(
        items: dtos.map(_toDomain).toList(growable: false),
        fromCache: false,
      );
    } on DioException catch (e) {
      // Cache serves ONLY connectivity-shaped failures. 401/403/422/5xx bubble
      // up so the error state renders — stale numbers must never mask a real
      // rejection (a BASIC-plan 403 in particular).
      final err = e.error;
      if (err is! OfflineException && err is! NetworkException) rethrow;
      final rows = await _dao.rowsForDateKey(dateKey);
      if (rows.isEmpty) rethrow; // nothing cached for this day — honest error
      return MyTargetsSnapshot(
        items: rows.map(_rowToDomain).toList(growable: false),
        fromCache: true,
      );
    }
  }

  @override
  Future<TargetDrillDownSlice> getDrillDown({
    required TargetMetric metric,
    required DateTime periodStart,
    required DateTime periodEnd,
    int limit = 50,
    String? cursor,
  }) async {
    // Network-only by contract: individual records aren't cached, offline
    // surfaces the error state.
    final page = await _api.drillDown(
      metric: targetMetricToWire(metric),
      periodStart: periodStart,
      periodEnd: periodEnd,
      limit: limit,
      cursor: cursor,
    );
    return TargetDrillDownSlice(
      items: page.items.map(_recordFromDto).toList(growable: false),
      nextCursor: page.nextCursor,
    );
  }

  TargetItem _toDomain(MyTargetDto dto) => TargetItem(
        id: dto.id,
        rule: dto.rule,
        metric: targetMetricFromWire(dto.metric),
        interval: targetIntervalFromWire(dto.interval),
        targetValue: dto.targetValue,
        actualValue: dto.actualValue,
        status: targetStatusFromWire(dto.status),
        isCurrency: dto.isCurrency,
        periodStart: dto.periodStart,
        periodEnd: dto.periodEnd,
        periodLabel: dto.periodLabel,
        periodStatus: targetPeriodStatusFromWire(dto.periodStatus),
      );

  /// Same codecs as [_toDomain] — a corrupt cached enum throws just as loudly
  /// as a corrupt wire one.
  TargetItem _rowToDomain(TargetRow row) => TargetItem(
        id: row.id,
        rule: row.rule,
        metric: targetMetricFromWire(row.metric),
        interval: targetIntervalFromWire(row.interval),
        targetValue: row.targetValue,
        actualValue: row.actualValue,
        status: targetStatusFromWire(row.status),
        isCurrency: row.isCurrency,
        periodStart: row.periodStart,
        periodEnd: row.periodEnd,
        periodLabel: row.periodLabel,
        periodStatus: targetPeriodStatusFromWire(row.periodStatus),
      );

  TargetsCompanion _companion(String dateKey, MyTargetDto dto) =>
      TargetsCompanion(
        dateKey: Value<String>(dateKey),
        id: Value<String>(dto.id),
        rule: Value<String>(dto.rule),
        metric: Value<String>(dto.metric),
        interval: Value<String>(dto.interval),
        targetValue: Value<double>(dto.targetValue),
        actualValue: Value<double>(dto.actualValue),
        status: Value<String>(dto.status),
        isCurrency: Value<bool>(dto.isCurrency),
        periodStart: Value<DateTime>(dto.periodStart),
        periodEnd: Value<DateTime>(dto.periodEnd),
        periodLabel: Value<String>(dto.periodLabel),
        periodStatus: Value<String>(dto.periodStatus),
        fetchedAt: Value<DateTime>(DateTime.now()),
      );

  TargetDrillDownRecord _recordFromDto(TargetTransactionDto dto) =>
      TargetDrillDownRecord(
        id: dto.id,
        primaryTitle: dto.title,
        subtitle: dto.subtitle,
        contributionValue: dto.value,
        isCurrency: dto.isCurrency,
        timestamp: dto.date,
        datePrecision: datePrecisionFromWire(dto.datePrecision),
      );
}

// ── Wire codecs ─────────────────────────────────────────────────────────────
// Top-level (collection precedent) so tests and row mappers can reach them.
// Unknown wire values throw: loud failure over silent misclassification.

TargetMetric targetMetricFromWire(String wire) => switch (wire) {
      'ORDER_COUNT' => TargetMetric.orderCount,
      'ORDER_VALUE' => TargetMetric.orderValue,
      'COLLECTION_COUNT' => TargetMetric.collectionCount,
      'COLLECTION_VALUE' => TargetMetric.collectionValue,
      'VISIT_COUNT' => TargetMetric.visitCount,
      'NEW_PARTY' => TargetMetric.newParty,
      'NEW_PROSPECT' => TargetMetric.newProspect,
      'NEW_SITE' => TargetMetric.newSite,
      _ => throw FormatException('Unsupported target metric: $wire'),
    };

String targetMetricToWire(TargetMetric metric) => switch (metric) {
      TargetMetric.orderCount => 'ORDER_COUNT',
      TargetMetric.orderValue => 'ORDER_VALUE',
      TargetMetric.collectionCount => 'COLLECTION_COUNT',
      TargetMetric.collectionValue => 'COLLECTION_VALUE',
      TargetMetric.visitCount => 'VISIT_COUNT',
      TargetMetric.newParty => 'NEW_PARTY',
      TargetMetric.newProspect => 'NEW_PROSPECT',
      TargetMetric.newSite => 'NEW_SITE',
    };

TargetInterval targetIntervalFromWire(String wire) => switch (wire) {
      'DAILY' => TargetInterval.daily,
      'MONTHLY' => TargetInterval.monthly,
      _ => throw FormatException('Unsupported target interval: $wire'),
    };

TargetStatus targetStatusFromWire(String wire) => switch (wire) {
      'ACTIVE' => TargetStatus.active,
      'COMPLETED' => TargetStatus.completed,
      _ => throw FormatException('Unsupported target status: $wire'),
    };

TargetPeriodStatus targetPeriodStatusFromWire(String wire) => switch (wire) {
      'IN_PROGRESS' => TargetPeriodStatus.inProgress,
      'CLOSED' => TargetPeriodStatus.closed,
      _ => throw FormatException('Unsupported target period status: $wire'),
    };

DatePrecision datePrecisionFromWire(String wire) => switch (wire) {
      'DAY' => DatePrecision.day,
      'INSTANT' => DatePrecision.instant,
      _ => throw FormatException('Unsupported date precision: $wire'),
    };

/// Provides the abstract [TargetsRepository] interface.
final targetsRepositoryProvider = Provider<TargetsRepository>((ref) {
  return TargetsRepositoryImpl(
    api: ref.watch(targetsApiProvider),
    dao: ref.watch(targetsDaoProvider),
  );
});
