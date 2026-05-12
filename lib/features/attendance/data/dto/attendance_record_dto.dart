/// Wire DTO for an attendance row. Hand-written placeholder until the
/// backend publishes the attendance endpoint and `tool/gen_dto.sh`
/// can generate this.
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

  factory AttendanceRecordDto.fromJson(Map<String, dynamic> json) =>
      AttendanceRecordDto(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        status: json['status'] as String,
        checkInAt: json['checkInAt'] == null
            ? null
            : DateTime.parse(json['checkInAt'] as String),
        checkOutAt: json['checkOutAt'] == null
            ? null
            : DateTime.parse(json['checkOutAt'] as String),
        checkInLat: (json['checkInLat'] as num?)?.toDouble(),
        checkInLng: (json['checkInLng'] as num?)?.toDouble(),
        checkInAddress: json['checkInAddress'] as String?,
        checkOutLat: (json['checkOutLat'] as num?)?.toDouble(),
        checkOutLng: (json['checkOutLng'] as num?)?.toDouble(),
        checkOutAddress: json['checkOutAddress'] as String?,
        markedByUserId: json['markedByUserId'] as String?,
        markedByName: json['markedByName'] as String?,
        markedByRole: json['markedByRole'] as String?,
      );

  final String id;
  final DateTime date;

  /// `'present' | 'absent' | 'leave' | 'halfDay' | 'weeklyOff'` on the
  /// wire — kept as a String to match what the backend will send. The
  /// repo translates to the `AttendanceStatus` enum at the boundary
  /// and throws `FormatException` on unknown values.
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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date.toIso8601String(),
        'status': status,
        if (checkInAt != null) 'checkInAt': checkInAt!.toIso8601String(),
        if (checkOutAt != null) 'checkOutAt': checkOutAt!.toIso8601String(),
        if (checkInLat != null) 'checkInLat': checkInLat,
        if (checkInLng != null) 'checkInLng': checkInLng,
        if (checkInAddress != null) 'checkInAddress': checkInAddress,
        if (checkOutLat != null) 'checkOutLat': checkOutLat,
        if (checkOutLng != null) 'checkOutLng': checkOutLng,
        if (checkOutAddress != null) 'checkOutAddress': checkOutAddress,
        if (markedByUserId != null) 'markedByUserId': markedByUserId,
        if (markedByName != null) 'markedByName': markedByName,
        if (markedByRole != null) 'markedByRole': markedByRole,
      };
}
