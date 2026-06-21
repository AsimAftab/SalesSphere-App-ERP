import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_status.dart';
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

/// The server's check-in gate that guards field-ops actions (starting an
/// odometer trip / unplanned visit) — surfaced client-side so the app can
/// prompt the rep before they fill out a form.
extension AttendanceCheckInGate on AttendanceTodayStatus {
  /// Whether today's attendance satisfies that gate. A self check-in stamps
  /// `checkInAt`; a manager-marked present/half-day record has no timestamp but
  /// still counts as present for the day. Absent / leave / weekly-off — or no
  /// record at all — do not.
  bool get isCheckedIn {
    final r = record;
    if (r == null) return false;
    if (r.hasCheckIn) return true;
    return r.status == AttendanceStatus.present ||
        r.status == AttendanceStatus.halfDay;
  }
}
