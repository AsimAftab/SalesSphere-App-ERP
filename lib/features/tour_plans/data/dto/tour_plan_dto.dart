/// Wire DTO for a tour-plan request/response. The backend create route
/// returns server-owned fields in the envelope's `data` object; create
/// requests only send the writable subset from [toCreateJson].
class TourPlanDto {
  const TourPlanDto({
    required this.id,
    required this.placeOfVisit,
    required this.startDate,
    required this.endDate,
    required this.purpose,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
  });

  factory TourPlanDto.fromJson(Map<String, dynamic> json) => TourPlanDto(
    id: json['id'] as String,
    placeOfVisit: json['placeOfVisit'] as String,
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: DateTime.parse(json['endDate'] as String),
    purpose: (json['purposeOfVisit'] as String?) ?? (json['purpose'] as String),
    status: json['status'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    rejectionReason: json['rejectionReason'] as String?,
  );

  final String id;

  final String placeOfVisit;

  final DateTime startDate;
  final DateTime endDate;

  final String purpose;

  /// `'PENDING' | 'APPROVED' | 'REJECTED'` on the backend response.
  /// Existing mock rows still use lowercase values.
  final String status;

  final DateTime createdAt;

  /// Reason for rejection (only present if status is rejected).
  final String? rejectionReason;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'placeOfVisit': placeOfVisit,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'purpose': purpose,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    if (rejectionReason != null) 'rejectionReason': rejectionReason,
  };

  Map<String, dynamic> toCreateJson() => <String, dynamic>{
    'placeOfVisit': placeOfVisit,
    'startDate': _dateOnly(startDate),
    'endDate': _dateOnly(endDate),
    'purposeOfVisit': purpose,
  };

  String _dateOnly(DateTime date) => date.toIso8601String().substring(0, 10);
}
