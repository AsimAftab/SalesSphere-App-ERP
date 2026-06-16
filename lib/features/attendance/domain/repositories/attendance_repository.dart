import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_today_status.dart';
import 'package:sales_sphere_erp/features/attendance/domain/monthly_report.dart';

/// Contract for the attendance data source. The concrete impl
/// (`AttendanceRepositoryImpl`) handles wire-DTO ↔ domain mapping and
/// — once the backend lands — drift persistence + outbox enqueue.
/// Tests substitute fakes via the Riverpod override.
abstract class AttendanceRepository {
  /// The month's per-day records plus the server-computed status tally
  /// for `year/month`, from `GET /attendance/my-monthly-report`.
  Future<MonthlyReport> getMonthlyReport(int year, int month);

  /// Today's record (or null) plus the org schedule + geofence config,
  /// from `GET /attendance/status/today`.
  Future<AttendanceTodayStatus> getTodayStatus();

  /// `POST /attendance/check-in`. The server stamps the time and uses the
  /// session for identity; coordinates + address are required. Returns the
  /// upserted record so the controller can fold it back into the cache.
  Future<AttendanceRecord> checkIn({
    required double latitude,
    required double longitude,
    required String address,
  });

  /// `PUT /attendance/check-out`. [isHalfDay] flags a half-day checkout.
  /// Returns the updated record.
  Future<AttendanceRecord> checkOut({
    required double latitude,
    required double longitude,
    required String address,
    required bool isHalfDay,
  });
}
