/// UI-facing credit-exposure snapshot for one party — what the backend's
/// order-intake credit check sees right now. Money values stay decimal
/// strings (the wire's accounting convention); the page formats them.
///
/// A null [creditLimitAmount] means unlimited — [availableCredit] is null
/// with it, and the exposure figures are still meaningful on their own.
class PartyCredit {
  const PartyCredit({
    required this.customerId,
    required this.postedOutstanding,
    required this.draftOrdersTotal,
    required this.totalExposure,
    this.creditLimitAmount,
    this.availableCredit,
  });

  final String customerId;

  /// Null = unlimited.
  final String? creditLimitAmount;

  /// Unpaid POSTED invoices.
  final String postedOutstanding;

  /// Pending DRAFT orders.
  final String draftOrdersTotal;

  /// `postedOutstanding + draftOrdersTotal`.
  final String totalExposure;

  /// Credit left before the backend blocks order create; negative =
  /// already over-limit, null = unlimited.
  final String? availableCredit;

  bool get isUnlimited => creditLimitAmount == null;

  /// True when the customer's exposure already exceeds the limit — the
  /// next order create will be rejected outright.
  bool get isOverLimit {
    final available = availableCredit;
    if (available == null) return false;
    return (double.tryParse(available) ?? 0) < 0;
  }
}
