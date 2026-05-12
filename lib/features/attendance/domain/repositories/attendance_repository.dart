import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';

/// Contract for the attendance data source. The concrete impl
/// (`AttendanceRepositoryImpl`) handles wire-DTO ↔ domain mapping and
/// — once the backend lands — drift persistence + outbox enqueue.
/// Tests substitute fakes via the Riverpod override.
abstract class AttendanceRepository {
  /// All records that fall within `year/month`. Sorted ascending by
  /// `date` so the calendar can index by `date.day` directly.
  Future<List<AttendanceRecord>> getMonth(int year, int month);

  /// Records the user's check-in timestamp + location for `at.date`.
  /// Returns the upserted record so the controller can fold it back
  /// into the cache without a second fetch.
  Future<AttendanceRecord> checkIn({
    required DateTime at,
    required String userId,
    required String userName,
    required String userRole,
    double? lat,
    double? lng,
    String? address,
  });

  /// Records the user's check-out on top of the same day's record.
  /// Throws `StateError` if no check-in exists for the day.
  Future<AttendanceRecord> checkOut({
    required DateTime at,
    double? lat,
    double? lng,
    String? address,
  });
}
