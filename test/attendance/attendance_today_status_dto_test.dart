import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/attendance/data/dto/attendance_record_dto.dart';

void main() {
  // Inner `data` object of GET /attendance/status/today (after the outer
  // {success, data} envelope is peeled). Mirrors the real sample, including
  // the malformed short `orgCheckInTime: "22"`.
  Map<String, dynamic> sample({bool withRecord = true}) => <String, dynamic>{
        'record': withRecord
            ? <String, dynamic>{
                'id': 'rec1',
                'date': '2026-06-15T00:00:00.000Z',
                'status': 'PRESENT',
                'checkInTime': '2026-06-15T15:44:27.008Z',
                'checkInLatitude': 27.7172,
                'checkInLongitude': 85.324,
                'checkInAddress': 'Durbar Marg, Kathmandu',
                'checkOutTime': null,
                'markedBy': <String, dynamic>{'id': 'u1', 'name': 'Asim Aftab'},
              }
            : null,
        'timezone': 'Asia/Kathmandu',
        'orgCheckInTime': '22',
        'orgCheckOutTime': '21:00',
        'orgHalfDayCheckOutTime': '14:00',
        'orgWeeklyOffDays': <String>['SATURDAY'],
        'orgEnableGeoFencingAttendance': false,
        'orgLatitude': 27.6766,
        'orgLongitude': 85.316,
        'orgAddress': 'Lalitpur-5, Pulchowk',
        'orgGoogleMapLink': 'https://maps.google.com/?q=27.6766,85.3160',
      };

  test('parses record + org config + geofence fields', () {
    final dto = AttendanceTodayStatusDto.fromJson(sample());

    expect(dto.record, isNotNull);
    expect(dto.record!.status, 'PRESENT');
    expect(dto.record!.markedByName, 'Asim Aftab');
    expect(dto.timezone, 'Asia/Kathmandu');
    expect(dto.orgCheckInTime, '22');
    expect(dto.orgWeeklyOffDays, <String>['SATURDAY']);
    expect(dto.orgEnableGeoFencingAttendance, isFalse);
    expect(dto.orgLatitude, 27.6766);
    expect(dto.orgLongitude, 85.316);
    expect(dto.orgGoogleMapLink, isNotNull);
  });

  test('tolerates a null record (nobody marked yet)', () {
    final dto = AttendanceTodayStatusDto.fromJson(sample(withRecord: false));
    expect(dto.record, isNull);
    expect(dto.orgWeeklyOffDays, <String>['SATURDAY']);
  });

  test('defaults missing geofence/days safely', () {
    final dto = AttendanceTodayStatusDto.fromJson(<String, dynamic>{
      'record': null,
      'timezone': 'Asia/Kathmandu',
    });
    expect(dto.orgEnableGeoFencingAttendance, isFalse);
    expect(dto.orgWeeklyOffDays, isEmpty);
    expect(dto.orgLatitude, isNull);
  });
}
