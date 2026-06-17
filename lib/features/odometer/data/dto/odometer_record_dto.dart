/// Wire DTO for the backend `OdometerRecord`. Hand-written until the schema is
/// published to `tool/openapi.json`. Enum strings (`status`, `startUnit`,
/// `stopUnit`) stay as `String` here; the repository maps them to domain enums
/// and throws on unknown values. Timestamps arrive as UTC ISO-8601 and are
/// converted to local; `date` is the org-TZ calendar day (`YYYY-MM-DD`).
class OdometerRecordDto {
  const OdometerRecordDto({
    required this.id,
    required this.tripNumber,
    required this.status,
    this.employeeId,
    this.date,
    this.startReading,
    this.startUnit,
    this.startImage,
    this.startDescription,
    this.startTime,
    this.startLocation,
    this.stopReading,
    this.stopUnit,
    this.stopImage,
    this.stopDescription,
    this.stopTime,
    this.stopLocation,
    this.distance,
    this.createdAt,
    this.updatedAt,
  });

  factory OdometerRecordDto.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(Object? v) =>
        v == null ? null : DateTime.parse(v as String).toLocal();

    DateTime? parseDay(Object? v) {
      if (v == null) return null;
      final d = DateTime.parse(v as String);
      return DateTime(d.year, d.month, d.day);
    }

    return OdometerRecordDto(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String?,
      date: parseDay(json['date']),
      tripNumber: (json['tripNumber'] as num?)?.toInt() ?? 1,
      status: json['status'] as String,
      startReading: (json['startReading'] as num?)?.toDouble(),
      startUnit: json['startUnit'] as String?,
      startImage: json['startImage'] as String?,
      startDescription: json['startDescription'] as String?,
      startTime: parseTs(json['startTime']),
      startLocation: TripLocationDto.fromJsonOrNull(json['startLocation']),
      stopReading: (json['stopReading'] as num?)?.toDouble(),
      stopUnit: json['stopUnit'] as String?,
      stopImage: json['stopImage'] as String?,
      stopDescription: json['stopDescription'] as String?,
      stopTime: parseTs(json['stopTime']),
      stopLocation: TripLocationDto.fromJsonOrNull(json['stopLocation']),
      distance: (json['distance'] as num?)?.toDouble(),
      createdAt: parseTs(json['createdAt']),
      updatedAt: parseTs(json['updatedAt']),
    );
  }

  final String id;
  final String? employeeId;
  final DateTime? date;
  final int tripNumber;

  /// `not_started` | `in_progress` | `completed` (lowercase on the wire).
  final String status;

  final double? startReading;

  /// `km` | `miles` (lowercase).
  final String? startUnit;
  final String? startImage;
  final String? startDescription;
  final DateTime? startTime;
  final TripLocationDto? startLocation;

  final double? stopReading;
  final String? stopUnit;
  final String? stopImage;
  final String? stopDescription;
  final DateTime? stopTime;
  final TripLocationDto? stopLocation;

  final double? distance;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// Nested `startLocation` / `stopLocation` object. The server omits it or sends
/// `null` when no fix was captured.
class TripLocationDto {
  const TripLocationDto({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  /// Returns `null` unless [raw] is a map carrying both coordinates.
  static TripLocationDto? fromJsonOrNull(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final lat = (raw['latitude'] as num?)?.toDouble();
    final lng = (raw['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return TripLocationDto(
      latitude: lat,
      longitude: lng,
      address: raw['address'] as String?,
    );
  }

  final double latitude;
  final double longitude;
  final String? address;
}
