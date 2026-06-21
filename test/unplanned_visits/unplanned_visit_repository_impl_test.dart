import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/data/dto/unplanned_visit_dto.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/data/dto/unplanned_visits_monthly_report_dto.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/data/dto/unplanned_visits_today_dto.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/data/repositories/unplanned_visit_repository_impl.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/data/unplanned_visits_api.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit_exceptions.dart';

/// Fake API: only the methods exercised per test are populated; the rest throw.
class _FakeApi implements UnplannedVisitsApi {
  _FakeApi({this.today, this.byId, this.monthly, this.startError});

  UnplannedVisitsTodayDto? today;
  UnplannedVisitDto? byId;
  UnplannedVisitsMonthlyReportDto? monthly;
  DioException? startError;

  @override
  Future<UnplannedVisitsTodayDto> fetchTodayStatus() async => today!;

  @override
  Future<UnplannedVisitDto> fetchById(String id) async => byId!;

  @override
  Future<UnplannedVisitsMonthlyReportDto> fetchMonthlyReport(
    int year,
    int month,
  ) async => monthly!;

  @override
  Future<UnplannedVisitDto> start({
    required String targetType,
    required String targetId,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    if (startError != null) throw startError!;
    throw UnimplementedError();
  }

  @override
  Future<UnplannedVisitDto> stop({
    required String imagePath,
    String? description,
    DateTime? followUpDate,
    double? latitude,
    double? longitude,
    String? address,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();
}

DioException _dioError(int status, Map<String, dynamic> body, {Object? mapped}) {
  final req = RequestOptions(path: '/unplanned-visits/start');
  return DioException(
    requestOptions: req,
    response: Response<Map<String, dynamic>>(
      requestOptions: req,
      statusCode: status,
      data: body,
    ),
    type: DioExceptionType.badResponse,
    error: mapped,
  );
}

Map<String, dynamic> _completedJson() => <String, dynamic>{
      'id': 'vis_1',
      'status': 'completed',
      'target': <String, dynamic>{
        'type': 'customer',
        'id': 'cus_1',
        'name': 'Acme Traders',
        'address': 'Putalisadak',
        'latitude': 27.70,
        'longitude': 85.31,
      },
      'startTime': '2026-06-17T03:49:00.000Z',
      'startLocation': <String, dynamic>{
        'latitude': 27.7,
        'longitude': 85.3,
        'address': 'Kathmandu',
      },
      'stopTime': '2026-06-17T04:35:00.000Z',
      'image': 'https://img/visit.jpg',
      'description': 'Discussed order.',
      'followUpDate': '2026-06-24',
      'durationSeconds': 2760,
      'createdAt': '2026-06-17T03:49:00.000Z',
      'updatedAt': '2026-06-17T04:35:00.000Z',
    };

void main() {
  group('getById → DTO→domain mapping', () {
    test('maps a completed visit with target + locations', () async {
      final repo = UnplannedVisitRepositoryImpl(
        api: _FakeApi(byId: UnplannedVisitDto.fromJson(_completedJson())),
      );

      final visit = await repo.getById('vis_1');

      expect(visit.id, 'vis_1');
      expect(visit.status, VisitStatus.completed);
      expect(visit.target.type, VisitTargetType.customer);
      expect(visit.target.displayName, 'Acme Traders');
      expect(visit.target.latitude, 27.70);
      expect(visit.imageUrl, 'https://img/visit.jpg');
      expect(visit.description, 'Discussed order.');
      expect(visit.followUpDate, DateTime.parse('2026-06-24'));
      expect(visit.durationSeconds, 2760);
      expect(visit.startLocation?.address, 'Kathmandu');
      expect(visit.stopLocation, isNull);
    });

    test('in-progress visit has null stop fields', () async {
      final json = _completedJson()
        ..['status'] = 'in_progress'
        ..remove('stopTime')
        ..remove('image')
        ..remove('durationSeconds');
      final repo = UnplannedVisitRepositoryImpl(
        api: _FakeApi(byId: UnplannedVisitDto.fromJson(json)),
      );

      final visit = await repo.getById('vis_1');

      expect(visit.status, VisitStatus.inProgress);
      expect(visit.isInProgress, isTrue);
      expect(visit.imageUrl, isNull);
      expect(visit.durationSeconds, isNull);
    });

    test('unknown status wire value throws loudly', () async {
      final json = _completedJson()..['status'] = 'bogus';
      final repo = UnplannedVisitRepositoryImpl(
        api: _FakeApi(byId: UnplannedVisitDto.fromJson(json)),
      );

      await expectLater(
        repo.getById('vis_1'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('getTodayStatus', () {
    test('exposes the active visit + completed list', () async {
      final active = _completedJson()
        ..['id'] = 'vis_2'
        ..['status'] = 'in_progress';
      final today = UnplannedVisitsTodayDto.fromJson(<String, dynamic>{
        'visits': <dynamic>[active, _completedJson()],
        'hasActiveVisit': true,
        'activeVisitId': 'vis_2',
      });
      final repo = UnplannedVisitRepositoryImpl(api: _FakeApi(today: today));

      final status = await repo.getTodayStatus();

      expect(status.visits.length, 2);
      expect(status.hasActiveVisit, isTrue);
      expect(status.activeVisit?.id, 'vis_2');
      expect(status.completedVisits.length, 1);
    });
  });

  group('getMonthlyReport → DTO→domain mapping', () {
    test('maps records + summary and sorts newest-first', () async {
      final older = _completedJson()
        ..['id'] = 'vis_old'
        ..['startTime'] = '2026-06-02T03:00:00.000Z';
      final newer = _completedJson()
        ..['id'] = 'vis_new'
        ..['startTime'] = '2026-06-20T03:00:00.000Z';
      final monthly = UnplannedVisitsMonthlyReportDto.fromJson(
        <String, dynamic>{
          'month': 6,
          'year': 2026,
          // Deliberately out of order to prove the repo re-sorts.
          'records': <dynamic>[older, newer],
          'summary': <String, dynamic>{
            'totalVisits': 2,
            'visitsCompleted': 2,
            'visitsInProgress': 0,
            'followUps': 2,
          },
        },
      );
      final repo = UnplannedVisitRepositoryImpl(api: _FakeApi(monthly: monthly));

      final report = await repo.getMonthlyReport(2026, 6);

      expect(report.year, 2026);
      expect(report.month, 6);
      expect(report.records.map((v) => v.id).toList(), <String>[
        'vis_new',
        'vis_old',
      ]);
      expect(report.summary.totalVisits, 2);
      expect(report.summary.visitsCompleted, 2);
      expect(report.summary.visitsInProgress, 0);
      expect(report.summary.followUps, 2);
    });

    test('empty month → empty records + zeroed summary', () async {
      final monthly = UnplannedVisitsMonthlyReportDto.fromJson(
        <String, dynamic>{'month': 1, 'year': 2026, 'records': <dynamic>[]},
      );
      final repo = UnplannedVisitRepositoryImpl(api: _FakeApi(monthly: monthly));

      final report = await repo.getMonthlyReport(2026, 1);

      expect(report.records, isEmpty);
      expect(report.summary.totalVisits, 0);
      expect(report.summary.followUps, 0);
    });
  });

  group('write errors → typed domain exceptions', () {
    test('409 UNPLANNED_VISIT_IN_PROGRESS → conflict exception', () async {
      final repo = UnplannedVisitRepositoryImpl(
        api: _FakeApi(
          startError: _dioError(409, <String, dynamic>{
            'success': false,
            'error': <String, dynamic>{
              'code': 'UNPLANNED_VISIT_IN_PROGRESS',
              'message': 'You already have an open visit.',
            },
          }),
        ),
      );

      await expectLater(
        repo.startVisit(
          targetType: VisitTargetType.customer,
          targetId: 'cus_1',
        ),
        throwsA(
          isA<UnplannedVisitConflictException>()
              .having((e) => e.code, 'code', 'UNPLANNED_VISIT_IN_PROGRESS'),
        ),
      );
    });

    test('generic error unwraps the interceptor ApiException', () async {
      final repo = UnplannedVisitRepositoryImpl(
        api: _FakeApi(
          startError: _dioError(
            500,
            <String, dynamic>{'success': false},
            mapped: const ServerException(),
          ),
        ),
      );

      await expectLater(
        repo.startVisit(
          targetType: VisitTargetType.customer,
          targetId: 'cus_1',
        ),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
