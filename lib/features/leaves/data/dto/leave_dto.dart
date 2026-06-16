/// Wire DTO for a leave request — the read model returned by the leaves
/// endpoints. Hand-written (mirrors the attendance DTO) until the leaves
/// schema is wired into `tool/gen_dto.sh`.
///
/// The backend always sends an explicit `endDate` (equal to `startDate`
/// for a single-day leave); the repository collapses that back to a null
/// `endDate` on the domain model so the UI keeps rendering single-day
/// leaves as one date. Request bodies are built in the repository, so this
/// DTO only needs `fromJson`.
class LeaveDto {
  const LeaveDto({
    required this.id,
    required this.category,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory LeaveDto.fromJson(Map<String, dynamic> json) => LeaveDto(
    id: json['id'] as String,
    category: json['category'] as String,
    startDate: _parseDate(json['startDate'] as String),
    endDate: _parseDate(json['endDate'] as String),
    reason: json['reason'] as String,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String id;

  /// One of the backend `LeaveCategory` enum values — `SICK_LEAVE`,
  /// `MATERNITY_LEAVE`, `PATERNITY_LEAVE`, `COMPASSIONATE_LEAVE`,
  /// `RELIGIOUS_HOLIDAYS`, `FAMILY_RESPONSIBILITY`, `MISCELLANEOUS`. The
  /// repository maps this to the `LeaveCategory` enum at the domain
  /// boundary.
  final String category;

  /// Org-local calendar day, rebuilt at local midnight so date formatting
  /// never shifts it across a timezone boundary. The backend stores the
  /// date as UTC-midnight of the org-TZ day, so the UTC Y/M/D components
  /// already are the intended calendar date.
  final DateTime startDate;

  /// Always present on the wire — equals [startDate] for a single-day
  /// leave. The repository collapses that case to a null domain `endDate`.
  final DateTime endDate;

  final String reason;

  /// `PENDING | APPROVED | REJECTED` on the wire.
  final String status;

  final DateTime createdAt;

  /// Parse an ISO date into a local-midnight [DateTime] whose Y/M/D match
  /// the backend's stored calendar day, regardless of device timezone.
  static DateTime _parseDate(String iso) {
    final d = DateTime.parse(iso);
    return DateTime(d.year, d.month, d.day);
  }
}
