/// Wire DTO for `GET /customers/{id}/credit` — the live credit-exposure
/// snapshot the backend computes when enforcing credit limits at order
/// intake. All money fields are decimal strings, per the backend's
/// convention for accounting values.
///
/// `creditLimitAmount` and `availableCredit` are null together when the
/// customer has no limit (unlimited — most customers). A negative
/// `availableCredit` means the customer is already over-limit.
///
/// Read-only and gated on `customers:view` — mobile never writes any of
/// this; the limit itself is set on web via a dedicated endpoint.
class PartyCreditDto {
  const PartyCreditDto({
    required this.customerId,
    required this.postedOutstanding,
    required this.draftOrdersTotal,
    required this.totalExposure,
    this.creditLimitAmount,
    this.availableCredit,
  });

  factory PartyCreditDto.fromJson(Map<String, dynamic> json) {
    return PartyCreditDto(
      customerId: json['customerId'] as String,
      creditLimitAmount: json['creditLimitAmount'] as String?,
      postedOutstanding: json['postedOutstanding'] as String,
      draftOrdersTotal: json['draftOrdersTotal'] as String,
      totalExposure: json['totalExposure'] as String,
      availableCredit: json['availableCredit'] as String?,
    );
  }

  final String customerId;

  /// Null = unlimited.
  final String? creditLimitAmount;

  /// Unpaid POSTED invoices.
  final String postedOutstanding;

  /// Pending DRAFT orders.
  final String draftOrdersTotal;

  /// `postedOutstanding + draftOrdersTotal`.
  final String totalExposure;

  /// `creditLimitAmount - totalExposure`; negative = over-limit,
  /// null = unlimited.
  final String? availableCredit;
}
