import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/geofence_config.dart';

/// Snapshot from `GET /attendance/status/today`: the signed-in user's record
/// for today ([record], null if nothing's been logged yet) plus the org
/// [geofence] config used by the client-side geofence gate.
///
/// The org work schedule is no longer carried here — the server owns the
/// check-in/out time windows and returns structured restriction details, so
/// the app reacts to those instead of re-deriving windows locally.
class AttendanceTodayStatus {
  const AttendanceTodayStatus({
    required this.record,
    required this.geofence,
  });

  final AttendanceRecord? record;
  final GeofenceConfig geofence;
}
