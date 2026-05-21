/// Wire DTO for a tour-plan request. Hand-written placeholder until the
/// backend publishes the tour-plans endpoint and `tool/gen_dto.sh` can
/// generate this.
class TourPlanDto {
  const TourPlanDto({
    required this.id,
    required this.placeOfVisit,
    required this.startDate,
    required this.endDate,
    required this.purpose,
    required this.status,
    required this.createdAt,
  });

  factory TourPlanDto.fromJson(Map<String, dynamic> json) => TourPlanDto(
    id: json['id'] as String,
    placeOfVisit: json['placeOfVisit'] as String,
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: DateTime.parse(json['endDate'] as String),
    purpose: json['purpose'] as String,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  final String id;

  final String placeOfVisit;

  final DateTime startDate;
  final DateTime endDate;

  final String purpose;

  /// `'pending' | 'approved' | 'rejected'` on the wire.
  final String status;

  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'placeOfVisit': placeOfVisit,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'purpose': purpose,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };
}
