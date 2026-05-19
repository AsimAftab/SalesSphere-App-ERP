/// Wire DTO for a leave request. Hand-written placeholder until the
/// backend publishes the leaves endpoint and `tool/gen_dto.sh` can
/// generate this.
class LeaveDto {
  const LeaveDto({
    required this.id,
    required this.category,
    required this.startDate,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.endDate,
  });

  factory LeaveDto.fromJson(Map<String, dynamic> json) => LeaveDto(
    id: json['id'] as String,
    category: json['category'] as String,
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: json['endDate'] == null
        ? null
        : DateTime.parse(json['endDate'] as String),
    reason: json['reason'] as String,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  final String id;

  /// `'sick' | 'casual' | 'annual' | 'maternity' | 'paternity' |
  /// 'bereavement' | 'unpaid'` on the wire — kept as a String to match
  /// what the backend will send. The repo translates to the
  /// `LeaveCategory` enum at the domain boundary.
  final String category;

  final DateTime startDate;

  /// Null when the request is for a single day (start == end implied).
  /// Omitted from `toJson` rather than serialised as null so the
  /// backend receives an absent key instead of a literal `null`.
  final DateTime? endDate;

  final String reason;

  /// `'pending' | 'approved' | 'rejected' | 'completed'` on the wire.
  final String status;

  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'category': category,
    'startDate': startDate.toIso8601String(),
    if (endDate != null) 'endDate': endDate!.toIso8601String(),
    'reason': reason,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };
}
