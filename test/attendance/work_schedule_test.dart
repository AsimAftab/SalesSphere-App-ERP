import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/attendance/domain/work_schedule.dart';

void main() {
  WorkSchedule schedule({bool enforce = true}) => WorkSchedule(
        scheduledCheckIn: const TimeOfDay(hour: 10, minute: 0),
        scheduledCheckOut: const TimeOfDay(hour: 18, minute: 0),
        scheduledHalfDayCheckOut: const TimeOfDay(hour: 13, minute: 0),
        weeklyOffDays: const <int>{DateTime.saturday},
        enforceWindows: enforce,
      );

  group('checkInStatus (windows enforced)', () {
    final s = schedule();
    // Window: 08:00 (−2h) … 10:30 (+30m) around a 10:00 start.
    test('too early before the window opens', () {
      expect(
        s.checkInStatus(DateTime(2026, 6, 15, 7)),
        CheckInWindowStatus.tooEarly,
      );
    });

    test('allowed inside the window', () {
      expect(
        s.checkInStatus(DateTime(2026, 6, 15, 9)),
        CheckInWindowStatus.allowed,
      );
    });

    test('too late after the window closes', () {
      expect(
        s.checkInStatus(DateTime(2026, 6, 15, 11)),
        CheckInWindowStatus.tooLate,
      );
    });
  });

  group('checkOutStatus (windows enforced)', () {
    final s = schedule();
    test('too early before any window', () {
      expect(
        s.checkOutStatus(DateTime(2026, 6, 15, 10)),
        CheckOutWindowStatus.tooEarly,
      );
    });

    test('half-day window open around 13:00', () {
      expect(
        s.checkOutStatus(DateTime(2026, 6, 15, 13)),
        CheckOutWindowStatus.halfDayAllowed,
      );
    });

    test('full-day window open from 17:30', () {
      expect(
        s.checkOutStatus(DateTime(2026, 6, 15, 18)),
        CheckOutWindowStatus.fullDayAllowed,
      );
    });
  });

  group('enforceWindows = false', () {
    final s = schedule(enforce: false);
    test('check-in is always allowed', () {
      expect(
        s.checkInStatus(DateTime(2026, 6, 15, 3)),
        CheckInWindowStatus.allowed,
      );
    });

    test('check-out is always full-day allowed', () {
      expect(
        s.checkOutStatus(DateTime(2026, 6, 15, 3)),
        CheckOutWindowStatus.fullDayAllowed,
      );
    });

    test('weekly-off still applies independently of windows', () {
      // 2026-06-13 is a Saturday.
      expect(s.isWeeklyOff(DateTime(2026, 6, 13)), isTrue);
      // 2026-06-15 is a Monday.
      expect(s.isWeeklyOff(DateTime(2026, 6, 15)), isFalse);
    });
  });
}
