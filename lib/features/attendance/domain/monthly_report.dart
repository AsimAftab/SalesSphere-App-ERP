import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/monthly_summary.dart';

/// A month's attendance as returned by `/attendance/my-monthly-report`:
/// the per-day [records] that paint the calendar, plus the
/// server-computed [summary] shown on the home page's summary card.
/// Bundling both lets the page derive the calendar and the summary from
/// a single round-trip.
class MonthlyReport {
  const MonthlyReport({required this.records, required this.summary});

  final List<AttendanceRecord> records;
  final MonthlySummary summary;
}
