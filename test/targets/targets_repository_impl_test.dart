import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/targets/data/dto/my_target_dto.dart';
import 'package:sales_sphere_erp/features/targets/data/dto/target_transaction_dto.dart';
import 'package:sales_sphere_erp/features/targets/data/dto/targets_drill_down_page_dto.dart';
import 'package:sales_sphere_erp/features/targets/data/repositories/targets_repository_impl.dart';
import 'package:sales_sphere_erp/features/targets/data/targets_api.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_enums.dart';

MyTargetDto _dto({
  String id = 't1',
  String metric = 'ORDER_COUNT',
  String interval = 'DAILY',
  String status = 'ACTIVE',
  String periodStatus = 'IN_PROGRESS',
}) {
  return MyTargetDto(
    id: id,
    rule: 'No. of Orders',
    metric: metric,
    interval: interval,
    targetValue: 99,
    actualValue: 1,
    status: status,
    isCurrency: false,
    periodStart: DateTime(2026, 7, 12),
    periodEnd: DateTime(2026, 7, 12),
    periodLabel: 'Jul 12, 2026',
    periodStatus: periodStatus,
  );
}

DioException _offline() => DioException(
      requestOptions: RequestOptions(path: '/targets/me'),
      error: const OfflineException(),
    );

DioException _forbidden() => DioException(
      requestOptions: RequestOptions(path: '/targets/me'),
      error: const ForbiddenException('Insufficient permissions'),
    );

/// Fake at the API seam — methods are virtual and the injected Dio is never
/// touched because both entry points are overridden.
class _FakeTargetsApi extends TargetsApi {
  _FakeTargetsApi() : super(Dio());

  List<MyTargetDto> myTargetsResult = <MyTargetDto>[];
  DioException? myTargetsError;
  DateTime? lastRequestedDate;

  TargetsDrillDownPageDto drillDownResult =
      const TargetsDrillDownPageDto(items: <TargetTransactionDto>[]);
  String? lastMetric;
  DateTime? lastPeriodStart;
  DateTime? lastPeriodEnd;
  String? lastCursor;

  @override
  Future<List<MyTargetDto>> myTargets({DateTime? date}) async {
    lastRequestedDate = date;
    final error = myTargetsError;
    if (error != null) throw error;
    return myTargetsResult;
  }

  @override
  Future<TargetsDrillDownPageDto> drillDown({
    required String metric,
    required DateTime periodStart,
    required DateTime periodEnd,
    int limit = 50,
    String? cursor,
  }) async {
    lastMetric = metric;
    lastPeriodStart = periodStart;
    lastPeriodEnd = periodEnd;
    lastCursor = cursor;
    return drillDownResult;
  }
}

void main() {
  late AppDatabase db;
  late _FakeTargetsApi api;
  late TargetsRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    api = _FakeTargetsApi();
    repo = TargetsRepositoryImpl(api: api, dao: db.targetsDao);
  });

  tearDown(() async => db.close());

  group('getMyTargets', () {
    test('maps wire DTOs to domain enums and caches under dateKey ""', () async {
      api.myTargetsResult = <MyTargetDto>[_dto()];

      final snapshot = await repo.getMyTargets();

      expect(snapshot.fromCache, isFalse);
      expect(api.lastRequestedDate, isNull);
      final item = snapshot.items.single;
      expect(item.metric, TargetMetric.orderCount);
      expect(item.interval, TargetInterval.daily);
      expect(item.status, TargetStatus.active);
      expect(item.periodStatus, TargetPeriodStatus.inProgress);

      final cached = await db.targetsDao.rowsForDateKey('');
      expect(cached, hasLength(1));
      expect(cached.single.metric, 'ORDER_COUNT');
    });

    test('explicit date caches under its own YYYY-MM-DD key', () async {
      api.myTargetsResult = <MyTargetDto>[_dto()];

      await repo.getMyTargets(date: DateTime(2026, 7, 10));

      expect(api.lastRequestedDate, DateTime(2026, 7, 10));
      expect(await db.targetsDao.rowsForDateKey('2026-07-10'), hasLength(1));
      expect(await db.targetsDao.rowsForDateKey(''), isEmpty);
    });

    test('throws FormatException on an unknown wire metric', () async {
      api.myTargetsResult = <MyTargetDto>[_dto(metric: 'BOGUS')];

      expect(repo.getMyTargets, throwsFormatException);
    });

    test('offline after a successful fetch serves cache with fromCache', () async {
      api.myTargetsResult = <MyTargetDto>[_dto()];
      await repo.getMyTargets();

      api.myTargetsError = _offline();
      final snapshot = await repo.getMyTargets();

      expect(snapshot.fromCache, isTrue);
      expect(snapshot.items.single.id, 't1');
    });

    test('offline with an empty cache rethrows — no fabricated data', () async {
      api.myTargetsError = _offline();

      expect(repo.getMyTargets, throwsA(isA<DioException>()));
    });

    test('offline cache is scoped per dateKey', () async {
      api.myTargetsResult = <MyTargetDto>[_dto()];
      await repo.getMyTargets(); // caches under '' only

      api.myTargetsError = _offline();
      // A never-fetched date has no cache — honest error, not today's rows.
      expect(
        () => repo.getMyTargets(date: DateTime(2026, 7)),
        throwsA(isA<DioException>()),
      );
    });

    test('non-connectivity failures rethrow without touching the cache',
        () async {
      api.myTargetsResult = <MyTargetDto>[_dto()];
      await repo.getMyTargets();

      // A 403 (e.g. BASIC plan) must surface, not silently serve stale rows.
      api.myTargetsError = _forbidden();
      expect(repo.getMyTargets, throwsA(isA<DioException>()));
    });
  });

  group('getDrillDown', () {
    test('passes wire metric and inclusive period through to the API',
        () async {
      api.drillDownResult = TargetsDrillDownPageDto(
        items: <TargetTransactionDto>[
          TargetTransactionDto(
            id: 'r1',
            title: 'ORD-DEVORG-HO-82-0003',
            subtitle: 'Pokhara Traders',
            value: 1,
            isCurrency: false,
            date: DateTime.parse('2026-07-12T00:00:00.000Z'),
            datePrecision: 'DAY',
          ),
        ],
        nextCursor: 'opaque-cursor',
      );

      final slice = await repo.getDrillDown(
        metric: TargetMetric.orderCount,
        periodStart: DateTime(2026, 7, 12),
        periodEnd: DateTime(2026, 7, 12),
        cursor: 'prev-cursor',
      );

      expect(api.lastMetric, 'ORDER_COUNT');
      expect(api.lastPeriodStart, DateTime(2026, 7, 12));
      expect(api.lastPeriodEnd, DateTime(2026, 7, 12));
      expect(api.lastCursor, 'prev-cursor');

      final record = slice.items.single;
      expect(record.primaryTitle, 'ORD-DEVORG-HO-82-0003');
      expect(record.subtitle, 'Pokhara Traders');
      expect(record.datePrecision, DatePrecision.day);
      expect(slice.nextCursor, 'opaque-cursor');
    });
  });

  group('wire codecs', () {
    test('every metric round-trips', () {
      for (final metric in TargetMetric.values) {
        expect(targetMetricFromWire(targetMetricToWire(metric)), metric);
      }
    });

    test('unknown wire values throw', () {
      expect(() => targetIntervalFromWire('Daily'), throwsFormatException);
      expect(() => targetStatusFromWire('Active'), throwsFormatException);
      expect(
        () => targetPeriodStatusFromWire('OPEN'),
        throwsFormatException,
      );
      expect(() => datePrecisionFromWire('TIME'), throwsFormatException);
    });
  });
}
