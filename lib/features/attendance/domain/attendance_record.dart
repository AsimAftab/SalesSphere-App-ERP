import 'package:sales_sphere_erp/features/attendance/domain/attendance_status.dart';

/// UI-facing attendance record. Decoupled from wire DTOs so backend
/// renames don't ripple into widgets. Will be promoted to freezed
/// once the attendance API + drift table land.
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.date,
    required this.status,
    this.checkInAt,
    this.checkOutAt,
    this.checkInLat,
    this.checkInLng,
    this.checkInAddress,
    this.checkOutLat,
    this.checkOutLng,
    this.checkOutAddress,
    this.markedByUserId,
    this.markedByName,
    this.markedByRole,
    this.isLate = false,
  });

  final String id;

  /// Midnight-normalized day this record represents. `checkInAt` /
  /// `checkOutAt` carry the actual timestamps when applicable.
  final DateTime date;
  final AttendanceStatus status;

  final DateTime? checkInAt;
  final DateTime? checkOutAt;

  final double? checkInLat;
  final double? checkInLng;
  final String? checkInAddress;

  final double? checkOutLat;
  final double? checkOutLng;
  final String? checkOutAddress;

  final String? markedByUserId;
  final String? markedByName;
  final String? markedByRole;

  /// A present day where check-in was after the scheduled start. On the
  /// calendar a late day still reads as Present (green); it's counted
  /// separately in the monthly summary's "Late" tally.
  final bool isLate;

  bool get hasCheckIn => checkInAt != null;
  bool get hasCheckOut => checkOutAt != null;

  /// Duration between check-in and check-out, or `null` when one of
  /// them is missing. Read by the details list's "Hours Worked" tile.
  Duration? get hoursWorked {
    final inAt = checkInAt;
    final outAt = checkOutAt;
    if (inAt == null || outAt == null) return null;
    return outAt.difference(inAt);
  }
}
