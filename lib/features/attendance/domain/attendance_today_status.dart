import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/geofence_config.dart';
import 'package:sales_sphere_erp/features/attendance/domain/work_schedule.dart';

/// Snapshot from `GET /attendance/status/today`: the signed-in user's record
/// for today ([record], null if nothing's been logged yet), the org work
/// [schedule] that gates the check-in/out time windows, and the [geofence]
/// configuration. Bundled so the home page derives the today card, the
/// check-in/out button, and the geofence gate from a single round-trip.
class AttendanceTodayStatus {
  const AttendanceTodayStatus({
    required this.record,
    required this.schedule,
    required this.geofence,
  });

  final AttendanceRecord? record;
  final WorkSchedule schedule;
  final GeofenceConfig geofence;
}
