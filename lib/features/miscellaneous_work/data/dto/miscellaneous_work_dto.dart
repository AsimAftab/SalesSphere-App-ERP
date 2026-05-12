/// Wire DTO for a miscellaneous-work row. Hand-written placeholder
/// until the backend publishes the endpoint and `tool/gen_dto.sh`
/// can generate this.
class MiscellaneousWorkDto {
  const MiscellaneousWorkDto({
    required this.id,
    required this.natureOfWork,
    required this.assignedBy,
    required this.workDate,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.imagePaths = const <String>[],
  });

  factory MiscellaneousWorkDto.fromJson(Map<String, dynamic> json) =>
      MiscellaneousWorkDto(
        id: json['id'] as String,
        natureOfWork: json['natureOfWork'] as String,
        assignedBy: json['assignedBy'] as String,
        workDate: DateTime.parse(json['workDate'] as String),
        address: json['address'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        imagePaths: (json['imagePaths'] as List<dynamic>?)
                ?.cast<String>()
                .toList(growable: false) ??
            const <String>[],
      );

  final String id;
  final String natureOfWork;
  final String assignedBy;
  final DateTime workDate;

  final String address;
  final double latitude;
  final double longitude;

  final List<String> imagePaths;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'natureOfWork': natureOfWork,
        'assignedBy': assignedBy,
        'workDate': workDate.toIso8601String(),
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': createdAt.toIso8601String(),
        if (imagePaths.isNotEmpty) 'imagePaths': imagePaths,
      };
}
