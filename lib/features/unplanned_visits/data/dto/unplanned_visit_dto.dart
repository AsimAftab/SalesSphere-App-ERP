/// Wire DTO for an unplanned-visit row, matching the backend's Visit object
/// (see `unplanned-visits-mobile-integration.md`). Hand-written until the
/// backend publishes the endpoint in the OpenAPI spec and `tool/gen_dto.sh`
/// can generate it.
class UnplannedVisitDto {
  const UnplannedVisitDto({
    required this.id,
    required this.status,
    required this.target,
    this.startTime,
    this.startLocation,
    this.stopTime,
    this.stopLocation,
    this.image,
    this.description,
    this.followUpDate,
    this.durationSeconds,
    this.createdAt,
    this.updatedAt,
  });

  factory UnplannedVisitDto.fromJson(Map<String, dynamic> json) =>
      UnplannedVisitDto(
        id: json['id'] as String,
        status: json['status'] as String,
        target: VisitTargetDto.fromJson(json['target'] as Map<String, dynamic>),
        startTime: _parseDate(json['startTime']),
        startLocation: _location(json['startLocation']),
        stopTime: _parseDate(json['stopTime']),
        stopLocation: _location(json['stopLocation']),
        image: json['image'] as String?,
        description: json['description'] as String?,
        followUpDate: _parseDate(json['followUpDate']),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
        createdAt: _parseDate(json['createdAt']),
        updatedAt: _parseDate(json['updatedAt']),
      );

  final String id;
  final String status;
  final VisitTargetDto target;
  final DateTime? startTime;
  final VisitLocationDto? startLocation;
  final DateTime? stopTime;
  final VisitLocationDto? stopLocation;
  final String? image;
  final String? description;
  final DateTime? followUpDate;
  final int? durationSeconds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static DateTime? _parseDate(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;

  static VisitLocationDto? _location(Object? raw) =>
      raw is Map<String, dynamic> ? VisitLocationDto.fromJson(raw) : null;
}

/// The denormalised entity a visit was made to.
class VisitTargetDto {
  const VisitTargetDto({
    required this.type,
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory VisitTargetDto.fromJson(Map<String, dynamic> json) => VisitTargetDto(
    type: json['type'] as String,
    id: json['id'] as String,
    name: (json['name'] as String?) ?? '',
    address: json['address'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );

  final String type;
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
}

class VisitLocationDto {
  const VisitLocationDto({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory VisitLocationDto.fromJson(Map<String, dynamic> json) =>
      VisitLocationDto(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        address: json['address'] as String?,
      );

  final double latitude;
  final double longitude;
  final String? address;
}
