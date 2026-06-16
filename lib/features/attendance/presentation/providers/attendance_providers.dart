import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_today_status.dart';
import 'package:sales_sphere_erp/features/attendance/domain/monthly_report.dart';
import 'package:sales_sphere_erp/features/attendance/domain/monthly_summary.dart';

// Re-export the repository provider so downstream consumers
// (controllers, tests) can depend on the contract surface without
// importing from `data/`.
export 'package:sales_sphere_erp/features/attendance/data/repositories/attendance_repository_impl.dart'
    show attendanceRepositoryProvider;

part 'attendance_providers.g.dart';

/// The month's report — per-day records + server-computed summary —
/// from `/attendance/my-monthly-report`. This is the single round-trip;
/// `attendanceMonth`, `attendanceMonthlySummary`, and `attendanceByDate`
/// all derive from it so consuming pages never refetch.
@riverpod
Future<MonthlyReport> attendanceMonthlyReport(
  Ref ref,
  int year,
  int month,
) async {
  return ref.watch(attendanceRepositoryProvider).getMonthlyReport(year, month);
}

/// Records for `year/month`, projected out of [attendanceMonthlyReport]
/// so the calendar and `attendanceByDate` keep their existing shape.
@riverpod
Future<List<AttendanceRecord>> attendanceMonth(
  Ref ref,
  int year,
  int month,
) async {
  final report = await ref.watch(
    attendanceMonthlyReportProvider(year, month).future,
  );
  return report.records;
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

/// Synchronous roll-up for the home page's "Monthly Summary" card,
/// taken straight from the server's tally on [attendanceMonthlyReport].
/// Reads `.value` so the card paints zeros while the month is loading
/// (instead of unwrapping an `AsyncLoading` and pushing a second
/// skeleton state to the user).
@riverpod
MonthlySummary attendanceMonthlySummary(Ref ref, int year, int month) {
  return ref.watch(attendanceMonthlyReportProvider(year, month)).value?.summary ??
      MonthlySummary.empty;
}

/// Today's status from `/attendance/status/today`: today's record, the org
/// work schedule (drives the check-in/out time-window gating), and the
/// geofence config. Single source of truth for the today card + button.
@riverpod
Future<AttendanceTodayStatus> attendanceTodayStatus(Ref ref) async {
  return ref.watch(attendanceRepositoryProvider).getTodayStatus();
}

/// Today's record (or `null` if the user hasn't been marked yet). Projected
/// off [attendanceTodayStatus] so the "Today's Status" pill stays in lockstep
/// with the schedule/geofence the Check In / Check Out button reads.
@riverpod
Future<AttendanceRecord?> todayAttendance(Ref ref) async {
  final status = await ref.watch(attendanceTodayStatusProvider.future);
  return status.record;
}
