import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/beat_plan/data/dto/beat_plan_dto.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan_stop.dart';

void main() {
  test('BeatPlanStopDto parses visit timing, notes, follow-up + photo', () {
    final dto = BeatPlanStopDto.fromJson(<String, dynamic>{
      'id': 's1',
      'kind': 'CUSTOMER',
      'status': 'VISITED',
      'visitStartedAt': '2026-06-14T09:05:00.000Z',
      'visitedAt': '2026-06-14T09:23:30.000Z',
      'visitDurationSec': 1110,
      'visitNotes': 'Restocked shelf, collected partial payment.',
      'followUpDate': '2026-06-20T00:00:00.000Z',
      'images': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'img1',
          'slot': 1,
          'url': 'https://cdn.example/visit.jpg',
          'sortOrder': 1,
        },
      ],
    });

    expect(dto.visitStartedAt, isNotNull);
    expect(dto.visitDurationSec, 1110);
    expect(dto.visitNotes, 'Restocked shelf, collected partial payment.');
    expect(dto.followUpDate, isNotNull);
    expect(dto.visitImageUrl, 'https://cdn.example/visit.jpg');
  });

  test('BeatPlanStopDto parses a skipped stop: skippedAt set, visitedAt null',
      () {
    final dto = BeatPlanStopDto.fromJson(<String, dynamic>{
      'id': 's2',
      'kind': 'CUSTOMER',
      'status': 'SKIPPED',
      // Server stamps skippedAt and leaves visitedAt null for a skip.
      'skippedAt': '2026-06-14T10:15:00.000Z',
      'visitedAt': null,
      'images': <Map<String, dynamic>>[],
    });

    expect(dto.skippedAt, isNotNull);
    expect(dto.visitedAt, isNull);
  });

  test('BeatPlanStop.timeSpentLabel formats the duration', () {
    BeatPlanStop withDuration(int? sec) => BeatPlanStop(
          id: 's',
          beatPlanId: 'b',
          kind: 'CUSTOMER',
          status: 'VISITED',
          visitDurationSec: sec,
        );

    expect(withDuration(1110).timeSpentLabel, '18m 30s');
    expect(withDuration(3660).timeSpentLabel, '1h 1m');
    expect(withDuration(45).timeSpentLabel, '45s');
    expect(withDuration(null).timeSpentLabel, isNull);
    expect(withDuration(0).timeSpentLabel, isNull); // never shows "0"
  });
}
