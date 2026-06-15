/// Wire DTO for an attendance row. Hand-written until the backend
/// publishes the attendance schema in `tool/openapi.json` and
/// `tool/gen_dto.sh` can generate this. `fromJson` decodes the shape
/// returned by `GET /attendance/my-monthly-report`; the mock check-in/
/// out path constructs DTOs directly via the constructor.
class AttendanceRecordDto {
  const AttendanceRecordDto({
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

  factory AttendanceRecordDto.fromJson(Map<String, dynamic> json) {
    // Timestamps arrive as UTC ISO-8601 (`...Z`); convert to local so
    // the UI formats them in the device's timezone.
    DateTime? parseTs(Object? v) =>
        v == null ? null : DateTime.parse(v as String).toLocal();

    // The day arrives as a UTC midnight timestamp standing in for a
    // calendar date. Read its UTC y/m/d so day-of-month indexing is
    // timezone-stable, then drop the time-of-day.
    final rawDate = DateTime.parse(json['date'] as String);

    // `markedBy` is a nested `{ id, name }` object on the wire.
    final markedBy = json['markedBy'];
    final markedByMap = markedBy is Map<String, dynamic> ? markedBy : null;

    return AttendanceRecordDto(
      id: json['id'] as String,
      date: DateTime(rawDate.year, rawDate.month, rawDate.day),
      status: json['status'] as String,
      checkInAt: parseTs(json['checkInTime']),
      checkOutAt: parseTs(json['checkOutTime']),
      checkInLat: (json['checkInLatitude'] as num?)?.toDouble(),
      checkInLng: (json['checkInLongitude'] as num?)?.toDouble(),
      checkInAddress: json['checkInAddress'] as String?,
      checkOutLat: (json['checkOutLatitude'] as num?)?.toDouble(),
      checkOutLng: (json['checkOutLongitude'] as num?)?.toDouble(),
      checkOutAddress: json['checkOutAddress'] as String?,
      markedByUserId: (markedByMap?['id'] ?? json['markedById']) as String?,
      markedByName: markedByMap?['name'] as String?,
      // markedByRole isn't in the report payload — left at its null default.
      isLate: (json['isLate'] as bool?) ?? false,
    );
  }

  final String id;
  final DateTime date;

  /// `'PRESENT' | 'ABSENT' | 'LEAVE' | 'HALF_DAY' | 'WEEKLY_OFF'` on the
  /// wire — kept as a String to match what the backend sends. The repo
  /// translates to the `AttendanceStatus` enum at the boundary and
  /// throws `FormatException` on unknown values. "Late" is not a status:
  /// a late day is `PRESENT` with [isLate] set.
  final String status;

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

  /// True when the check-in landed after the org's scheduled start.
  final bool isLate;
}

/// Envelope returned by `GET /attendance/my-monthly-report` (after the
/// outer `{success, data}` wrapper is unwrapped): the month's rows plus
/// a server-computed status tally. The tally keys are the wire status
/// names (`PRESENT`, `ABSENT`, `HALF_DAY`, `LEAVE`, `WEEKLY_OFF`) plus a
/// `LATE` count that overlaps `PRESENT`.
class MonthlyReportDto {
  const MonthlyReportDto({required this.records, required this.summary});

  factory MonthlyReportDto.fromJson(Map<String, dynamic> json) {
    final rawList = json['data'];
    final records = rawList is List
        ? rawList
            .map((e) => AttendanceRecordDto.fromJson(e as Map<String, dynamic>))
            .toList(growable: false)
        : const <AttendanceRecordDto>[];

    final rawSummary = json['summary'];
    final summary = <String, int>{};
    if (rawSummary is Map) {
      rawSummary.forEach((key, value) {
        if (key is String && value is num) summary[key] = value.toInt();
      });
    }

    return MonthlyReportDto(records: records, summary: summary);
  }

  final List<AttendanceRecordDto> records;
  final Map<String, int> summary;
}

/// Envelope returned by `GET /attendance/status/today` (after the outer
/// `{success, data}` wrapper is unwrapped): today's [record] (null when the
/// user hasn't been marked yet), the org timezone + shift times (HH:MM
/// strings, possibly short like `"22"` or null), the weekly off-day names,
/// and the geofence config (enabled flag + office anchor).
class AttendanceTodayStatusDto {
  const AttendanceTodayStatusDto({
    required this.record,
    required this.timezone,
    required this.orgCheckInTime,
    required this.orgCheckOutTime,
    required this.orgHalfDayCheckOutTime,
    required this.orgWeeklyOffDays,
    required this.orgEnableGeoFencingAttendance,
    required this.orgLatitude,
    required this.orgLongitude,
    required this.orgAddress,
    required this.orgGoogleMapLink,
  });

  factory AttendanceTodayStatusDto.fromJson(Map<String, dynamic> json) {
    final rawRecord = json['record'];
    final record = rawRecord is Map<String, dynamic>
        ? AttendanceRecordDto.fromJson(rawRecord)
        : null;

    final rawDays = json['orgWeeklyOffDays'];
    final weeklyOff = rawDays is List
        ? rawDays.whereType<String>().toList(growable: false)
        : const <String>[];

    return AttendanceTodayStatusDto(
      record: record,
      timezone: json['timezone'] as String?,
      orgCheckInTime: json['orgCheckInTime'] as String?,
      orgCheckOutTime: json['orgCheckOutTime'] as String?,
      orgHalfDayCheckOutTime: json['orgHalfDayCheckOutTime'] as String?,
      orgWeeklyOffDays: weeklyOff,
      orgEnableGeoFencingAttendance:
          (json['orgEnableGeoFencingAttendance'] as bool?) ?? false,
      orgLatitude: (json['orgLatitude'] as num?)?.toDouble(),
      orgLongitude: (json['orgLongitude'] as num?)?.toDouble(),
      orgAddress: json['orgAddress'] as String?,
      orgGoogleMapLink: json['orgGoogleMapLink'] as String?,
    );
  }

  final AttendanceRecordDto? record;
  final String? timezone;
  final String? orgCheckInTime;
  final String? orgCheckOutTime;
  final String? orgHalfDayCheckOutTime;
  final List<String> orgWeeklyOffDays;
  final bool orgEnableGeoFencingAttendance;
  final double? orgLatitude;
  final double? orgLongitude;
  final String? orgAddress;
  final String? orgGoogleMapLink;
}
