import 'package:sales_sphere_erp/features/expenses/domain/expense_category.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_party.dart';

/// Workflow status of an expense claim. The approver moves a claim
/// from `pending` to `approved` or `rejected`. Drives whether the
/// detail page opens editable or read-only — only `pending` claims are
/// user-mutable.
enum ExpenseClaimStatus { pending, approved, rejected }

/// Display label for the status badge / banner.
String expenseClaimStatusLabel(ExpenseClaimStatus s) => switch (s) {
  ExpenseClaimStatus.pending => 'Pending',
  ExpenseClaimStatus.approved => 'Approved',
  ExpenseClaimStatus.rejected => 'Rejected',
};

/// UI-facing expense-claim model. Decoupled from any wire DTO so a
/// future backend rename doesn't ripple into widgets. Carries the same
/// approval workflow shape as `TourPlan` (status + optional rejection
/// reason) so the two features read as the same family.
class ExpenseClaim {
  const ExpenseClaim({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.status,
    required this.createdAt,
    this.party,
    this.description = '',
    this.imagePaths = const <String>[],
    this.rejectionReason,
  });

  final String id;
  final String title;

  /// Claimed amount in NPR. Stored as a raw number; the UI formats it
  /// with the `Rs` prefix.
  final double amount;

  /// The day the expense was incurred (date-only in intent).
  final DateTime date;

  final ExpenseCategory category;

  /// Approval workflow state. New claims start `pending`; the approver
  /// moves them to approved / rejected, and approved claims can be
  /// marked completed.
  final ExpenseClaimStatus status;

  /// Optional party the expense is associated with (e.g. a client
  /// visit). `null` when the claim isn't tied to a party.
  final ExpenseParty? party;

  /// Optional free-text note describing the expense.
  final String description;

  /// Up to two attached receipt image paths (gallery picks). Empty
  /// when none have been added.
  final List<String> imagePaths;

  /// Reason for rejection (only present when [status] is rejected).
  final String? rejectionReason;

  /// When the claim row was created locally. Drives the list ordering.
  final DateTime createdAt;

  /// Convenience copy used by the edit flow to produce an updated row.
  ExpenseClaim copyWith({
    String? title,
    double? amount,
    DateTime? date,
    ExpenseCategory? category,
    ExpenseClaimStatus? status,
    ExpenseParty? party,
    bool clearParty = false,
    String? description,
    List<String>? imagePaths,
    String? rejectionReason,
  }) {
    return ExpenseClaim(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      status: status ?? this.status,
      party: clearParty ? null : (party ?? this.party),
      description: description ?? this.description,
      imagePaths: imagePaths ?? this.imagePaths,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
    );
  }
}
