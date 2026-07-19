/// Wire DTOs for the attendance API. Hand-written until the backend schema is
/// published to `tool/openapi.json` and `tool/gen_dto.sh` can generate them.
///
/// The backend nests location under `checkIn` / `checkOut` objects, sends the
/// day as an org-timezone calendar date (`"YYYY-MM-DD"`), and uppercases the
/// status. `markedBy` / `employee` only appear on report/admin views.
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
  });

  factory AttendanceRecordDto.fromJson(Map<String, dynamic> json) {
    // Timestamps arrive as UTC ISO-8601 (`...Z`); convert to local so the UI
    // formats them in the device's timezone.
    DateTime? parseTs(Object? v) =>
        v == null ? null : DateTime.parse(v as String).toLocal();

    // `date` is the org-TZ calendar date ("YYYY-MM-DD"); keep just y/m/d so
    // day-of-month indexing is timezone-stable.
    final rawDate = DateTime.parse(json['date'] as String);

    final checkIn = json['checkIn'];
    final checkInMap = checkIn is Map<String, dynamic> ? checkIn : null;
    final checkOut = json['checkOut'];
    final checkOutMap = checkOut is Map<String, dynamic> ? checkOut : null;

    final markedBy = json['markedBy'];
    final markedByMap = markedBy is Map<String, dynamic> ? markedBy : null;

    return AttendanceRecordDto(
      id: json['id'] as String,
      date: DateTime(rawDate.year, rawDate.month, rawDate.day),
      status: json['status'] as String,
      checkInAt: parseTs(checkInMap?['time']),
      checkOutAt: parseTs(checkOutMap?['time']),
      checkInLat: (checkInMap?['latitude'] as num?)?.toDouble(),
      checkInLng: (checkInMap?['longitude'] as num?)?.toDouble(),
      checkInAddress: checkInMap?['address'] as String?,
      checkOutLat: (checkOutMap?['latitude'] as num?)?.toDouble(),
      checkOutLng: (checkOutMap?['longitude'] as num?)?.toDouble(),
      checkOutAddress: checkOutMap?['address'] as String?,
      markedByUserId: markedByMap?['id'] as String?,
      markedByName: markedByMap?['name'] as String?,
      markedByRole: markedByMap?['role'] as String?,
    );
  }

  final String id;
  final DateTime date;

  /// `'PRESENT' | 'ABSENT' | 'LEAVE' | 'HALF_DAY' | 'WEEKLY_OFF'` on the wire.
  /// The repo translates to the `AttendanceStatus` enum and throws on unknown
  /// values.
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
}

/// `data` of `GET /attendance/my-monthly-report`: a server-computed status
/// tally plus the month's rows. The tally keys are the wire status names
/// (`PRESENT`, `ABSENT`, `HALF_DAY`, `LEAVE`, `WEEKLY_OFF`).
class MonthlyReportDto {
  const MonthlyReportDto({required this.records, required this.summary});

  factory MonthlyReportDto.fromJson(Map<String, dynamic> json) {
    final rawList = json['records'];
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

/// `data` of `GET /attendance/status/today`: today's [record] (null when
/// nobody's marked yet) plus the org geofence config. The org schedule is also
/// returned by the backend but the app no longer gates windows locally — the
/// server is authoritative and returns structured restriction details — so it
/// isn't parsed here.
class AttendanceTodayStatusDto {
  const AttendanceTodayStatusDto({
    required this.record,
    required this.geofenceEnabled,
    required this.geofenceLatitude,
    required this.geofenceLongitude,
    required this.geofenceAddress,
    required this.geofenceGoogleMapLink,
  });

  factory AttendanceTodayStatusDto.fromJson(Map<String, dynamic> json) {
    final rawRecord = json['record'];
    final record = rawRecord is Map<String, dynamic>
        ? AttendanceRecordDto.fromJson(rawRecord)
        : null;

    final geo = json['geofence'];
    final geoMap = geo is Map<String, dynamic> ? geo : const <String, dynamic>{};

    return AttendanceTodayStatusDto(
      record: record,
      geofenceEnabled: (geoMap['enabled'] as bool?) ?? false,
      geofenceLatitude: (geoMap['latitude'] as num?)?.toDouble(),
      geofenceLongitude: (geoMap['longitude'] as num?)?.toDouble(),
      geofenceAddress: geoMap['address'] as String?,
      geofenceGoogleMapLink: geoMap['googleMapLink'] as String?,
    );
  }

  final AttendanceRecordDto? record;
  final bool geofenceEnabled;
  final double? geofenceLatitude;
  final double? geofenceLongitude;
  final String? geofenceAddress;
  final String? geofenceGoogleMapLink;
}
