import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_status.dart';
import 'package:sales_sphere_erp/features/attendance/domain/monthly_summary.dart';

// Re-export the repository provider so downstream consumers
// (controllers, tests) can depend on the contract surface without
// importing from `data/`.
export 'package:sales_sphere_erp/features/attendance/data/repositories/attendance_repository_impl.dart'
    show attendanceRepositoryProvider;

part 'attendance_providers.g.dart';

/// Records for `year/month`. Single fetch is fanned out into the
/// calendar, monthly summary, and `attendanceByDate` derived
/// providers, so consuming pages never duplicate the round-trip.
@riverpod
Future<List<AttendanceRecord>> attendanceMonth(
  Ref ref,
  int year,
  int month,
) async {
  return ref.watch(attendanceRepositoryProvider).getMonth(year, month);
}

/// Single day's record (or `null` if no attendance was logged). Pulled
/// from the surrounding month's cached list so the day-detail page
/// doesn't refetch when the user navigates around the calendar.
@riverpod
Future<AttendanceRecord?> attendanceByDate(Ref ref, DateTime date) async {
  final records = await ref.watch(
    attendanceMonthProvider(date.year, date.month).future,
  );
  for (final r in records) {
    if (r.date.year == date.year &&
        r.date.month == date.month &&
        r.date.day == date.day) {
      return r;
    }
  }
  return null;
}

/// Synchronous roll-up for the home page's "Monthly Summary" card.
/// Reads `.valueOrNull` so the card paints zeros while the underlying
/// month is loading (instead of unwrapping an `AsyncLoading` and
/// pushing a second skeleton state to the user).
@riverpod
MonthlySummary attendanceMonthlySummary(Ref ref, int year, int month) {
  final records = ref.watch(attendanceMonthProvider(year, month)).value;
  if (records == null) return MonthlySummary.empty;

  var present = 0;
  var absent = 0;
  var leave = 0;
  var halfDay = 0;
  var weeklyOff = 0;
  for (final r in records) {
    switch (r.status) {
      case AttendanceStatus.present:
        present++;
      case AttendanceStatus.absent:
        absent++;
      case AttendanceStatus.leave:
        leave++;
      case AttendanceStatus.halfDay:
        halfDay++;
      case AttendanceStatus.weeklyOff:
        weeklyOff++;
    }
  }

  // Half-day counts as 0.5 of a working day; weekly-offs are excluded
  // from the denominator since they aren't attendance opportunities.
  final workingDays = present + absent + leave + halfDay;
  final attendancePct = workingDays == 0
      ? 0.0
      : ((present + halfDay * 0.5) / workingDays) * 100;

  return MonthlySummary(
    present: present,
    absent: absent,
    leave: leave,
    halfDay: halfDay,
    weeklyOff: weeklyOff,
    attendancePct: attendancePct,
  );
}

/// Today's record (or `null` if the user hasn't checked in yet).
/// Powers the home page's "Today's Status" pill and the Check In /
/// Check Out button label.
@riverpod
Future<AttendanceRecord?> todayAttendance(Ref ref) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return ref.watch(attendanceByDateProvider(today).future);
}
