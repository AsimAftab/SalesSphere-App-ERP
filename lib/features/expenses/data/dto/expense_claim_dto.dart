/// Wire DTO for an expense claim — the read model returned by the
/// `/expense-claims` endpoints, plus the writable subset emitted by
/// [toJson]. Hand-written (mirrors the notes / leaves DTOs) until the
/// expense-claims schema is wired into `tool/gen_dto.sh`.
///
/// The server owns identity + time + status: `id`, `status`,
/// `rejectionReason`, `createdAt` and the employee id are all read-only.
/// [toJson] therefore only emits the writable fields (`title`, `amount`,
/// `date`, `category`, `description`, `partyId`).
class ExpenseClaimDto {
  const ExpenseClaimDto({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.status,
    required this.description,
    required this.createdAt,
    this.partyId,
    this.party,
    this.rejectionReason,
  });

  factory ExpenseClaimDto.fromJson(Map<String, dynamic> json) =>
      ExpenseClaimDto(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: _parseDate(json['date'] as String),
        category: (json['category'] as String?) ?? '',
        status: json['status'] as String,
        description: (json['description'] as String?) ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        partyId: json['partyId'] as String?,
        party: json['party'] == null
            ? null
            : ExpenseClaimPartyDto.fromJson(
                json['party'] as Map<String, dynamic>,
              ),
        rejectionReason: json['rejectionReason'] as String?,
      );

  final String id;
  final String title;

  /// NPR raw number; the app formats it with a `Rs` prefix.
  final double amount;

  /// Org-local calendar day, rebuilt at local midnight so date formatting
  /// never shifts it across a device timezone boundary. The backend stores
  /// the date as UTC-midnight of the org-TZ day, so the UTC Y/M/D
  /// components already are the intended calendar date.
  final DateTime date;

  /// The catalogue row **name** (a free string, e.g. `"Travel"`).
  final String category;

  /// `PENDING | APPROVED | REJECTED` on the wire.
  final String status;

  final String description;
  final DateTime createdAt;

  /// Optional Customer FK. `null` when the claim isn't linked to a party.
  final String? partyId;

  /// Embedded party label returned on read whenever [partyId] is set.
  final ExpenseClaimPartyDto? party;

  /// Only set when [status] is `REJECTED`.
  final String? rejectionReason;

  /// Writable subset sent on create / update. `partyId` is always emitted
  /// (even when null) so a PATCH can clear the party link; the backend
  /// treats explicit null as a clear. `status` / `rejectionReason` are
  /// server-owned and never sent.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'amount': amount,
    'date': _dateToWire(date),
    'category': category,
    'description': description,
    'partyId': partyId,
  };

  /// Parse an ISO date into a local-midnight [DateTime] whose Y/M/D match
  /// the backend's stored calendar day, regardless of device timezone.
  static DateTime _parseDate(String iso) {
    final d = DateTime.parse(iso);
    return DateTime(d.year, d.month, d.day);
  }

  /// Wire date format: a bare `yyyy-MM-dd` calendar day. Sending a
  /// date-only string avoids any timezone drift a full timestamp could
  /// introduce (same convention as leaves `startDate`).
  static String _dateToWire(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Embedded party label on the read model (`party { id, companyName }`).
class ExpenseClaimPartyDto {
  const ExpenseClaimPartyDto({required this.id, required this.companyName});

  factory ExpenseClaimPartyDto.fromJson(Map<String, dynamic> json) =>
      ExpenseClaimPartyDto(
        id: json['id'] as String,
        companyName: (json['companyName'] as String?) ?? '',
      );

  final String id;
  final String companyName;
}
