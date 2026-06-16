import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/attendance/data/dto/attendance_record_dto.dart';

void main() {
  // Inner `data` of GET /attendance/status/today (after the {success,data}
  // envelope is peeled): nested record + geofence group.
  Map<String, dynamic> sample({bool withRecord = true, bool geofence = false}) =>
      <String, dynamic>{
        'record': withRecord
            ? <String, dynamic>{
                'id': 'att_1',
                'date': '2026-06-16',
                'status': 'PRESENT',
                'checkIn': <String, dynamic>{
                  'time': '2026-06-16T03:12:05.000Z',
                  'latitude': 27.7172,
                  'longitude': 85.324,
                  'address': 'Durbar Marg, Kathmandu',
                },
                'checkOut': null,
                'isLate': true,
                'markedBy': <String, dynamic>{'id': 'usr_1', 'name': 'Asim Aftab'},
              }
            : null,
        'schedule': <String, dynamic>{
          'checkInTime': '09:00',
          'checkOutTime': '17:00',
          'halfDayCheckOutTime': '13:00',
          'weeklyOffDays': <String>['SATURDAY'],
          'timezone': 'Asia/Kathmandu',
        },
        'geofence': <String, dynamic>{
          'enabled': geofence,
          'latitude': 27.6766,
          'longitude': 85.316,
          'address': 'Acme HQ',
          'googleMapLink': 'https://maps.google.com/?q=27.6766,85.3160',
        },
      };

  group('AttendanceTodayStatusDto', () {
    test('parses the nested record + geofence group', () {
      final dto = AttendanceTodayStatusDto.fromJson(sample(geofence: true));

      expect(dto.record, isNotNull);
      expect(dto.record!.status, 'PRESENT');
      expect(dto.record!.isLate, isTrue);
      expect(dto.geofenceEnabled, isTrue);
      expect(dto.geofenceLatitude, 27.6766);
      expect(dto.geofenceAddress, 'Acme HQ');
      expect(dto.geofenceGoogleMapLink, isNotNull);
    });

    test('tolerates a null record and a missing geofence', () {
      final dto = AttendanceTodayStatusDto.fromJson(<String, dynamic>{
        'record': null,
        'schedule': null,
      });
      expect(dto.record, isNull);
      expect(dto.geofenceEnabled, isFalse);
      expect(dto.geofenceLatitude, isNull);
    });
  });

  group('AttendanceRecordDto.fromJson (nested wire shape)', () {
    test('flattens checkIn/checkOut/markedBy and the date', () {
      final dto = AttendanceRecordDto.fromJson(<String, dynamic>{
        'id': 'att_2',
        'date': '2026-06-16',
        'status': 'HALF_DAY',
        'checkIn': <String, dynamic>{
          'time': '2026-06-16T03:12:05.000Z',
          'latitude': 27.7172,
          'longitude': 85.324,
          'address': 'Kathmandu',
        },
        'checkOut': <String, dynamic>{
          'time': '2026-06-16T07:30:00.000Z',
          'latitude': 27.7172,
          'longitude': 85.324,
          'address': 'Kathmandu',
        },
        'isLate': false,
        'markedBy': <String, dynamic>{'id': 'usr_9', 'name': 'Asha Rai'},
      });

      expect(dto.id, 'att_2');
      expect(dto.date, DateTime(2026, 6, 16));
      expect(dto.status, 'HALF_DAY');
      expect(dto.checkInAt, isNotNull);
      expect(dto.checkInLat, 27.7172);
      expect(dto.checkInAddress, 'Kathmandu');
      expect(dto.checkOutAt, isNotNull);
      expect(dto.markedByName, 'Asha Rai');
      expect(dto.markedByUserId, 'usr_9');
    });

    test('handles a record with no check-in/out yet', () {
      final dto = AttendanceRecordDto.fromJson(<String, dynamic>{
        'id': 'att_3',
        'date': '2026-06-16',
        'status': 'ABSENT',
        'checkIn': null,
        'checkOut': null,
      });
      expect(dto.checkInAt, isNull);
      expect(dto.checkOutAt, isNull);
      expect(dto.isLate, isFalse);
      expect(dto.markedByName, isNull);
    });
  });
}
