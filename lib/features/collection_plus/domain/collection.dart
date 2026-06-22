import 'package:sales_sphere_erp/features/collection_plus/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_allocation.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/payment_mode.dart';

/// UI-facing collection model — one recorded payment received from a
/// party. Decoupled from any wire DTO so a future backend rename
/// doesn't ripple into widgets.
///
/// A collection is a plain receipt: unlike expense claims / leaves it
/// carries no approval workflow. The bank / cheque fields are only
/// populated when [paymentMode] calls for them
/// ([PaymentModeX.requiresBank] / [PaymentModeX.requiresChequeDetails]).
class CollectionPlus {
  const CollectionPlus({
    required this.id,
    required this.allocations,
    required this.party,
    required this.amount,
    required this.receivedDate,
    required this.paymentMode,
    required this.createdAt,
    this.bankName,
    this.chequeNumber,
    this.chequeDate,
    this.chequeStatus,
    this.description = '',
    this.imagePaths = const <String>[],
  });

  final String id;

  /// How [amount] was split across the party's outstanding invoices,
  /// oldest-first (FIFO). Always holds at least one entry; more than one
  /// when a single payment spilled across invoices. Each entry reflects
  /// as a credit against its invoice on the accounting side.
  final List<CollectionPlusAllocation> allocations;

  /// The party the payment was collected from. Denormalised here so the
  /// list card can render it without resolving the allocations.
  final CollectionPlusParty party;

  /// Amount received in NPR. Stored as a raw number; the UI formats it
  /// with the `Rs` prefix.
  final double amount;

  /// The day the payment was received (date-only in intent).
  final DateTime receivedDate;

  final PaymentMode paymentMode;

  /// Bank the money moved through. Present only for cheque / bank
  /// transfer ([PaymentModeX.requiresBank]); `null` otherwise.
  final String? bankName;

  /// Cheque number — present only for a cheque collection.
  final String? chequeNumber;

  /// Date written on the cheque — present only for a cheque collection.
  final DateTime? chequeDate;

  /// Clearing state of the cheque — present only for a cheque
  /// collection.
  final ChequeStatus? chequeStatus;

  /// Optional free-text note describing the collection.
  final String description;

  /// Up to two attached payment-proof image paths (gallery picks).
  /// Empty when none have been added.
  final List<String> imagePaths;

  /// When the collection row was created locally. Drives list ordering.
  final DateTime createdAt;

  /// Document numbers this payment settled, for the list / detail cards:
  /// `ORD-2026-0006` for one invoice, `ORD-2026-0006 +1 more` when the
  /// payment spilled across several.
  String get invoiceSummary {
    if (allocations.isEmpty) return '';
    final first = allocations.first.invoiceNumber;
    if (allocations.length == 1) return first;
    return '$first +${allocations.length - 1} more';
  }

  /// Convenience copy used by the edit flow. The `clear*` flags null
  /// out the bank / cheque fields when switching to a payment mode that
  /// no longer needs them.
  CollectionPlus copyWith({
    List<CollectionPlusAllocation>? allocations,
    CollectionPlusParty? party,
    double? amount,
    DateTime? receivedDate,
    PaymentMode? paymentMode,
    String? bankName,
    bool clearBankName = false,
    String? chequeNumber,
    bool clearChequeNumber = false,
    DateTime? chequeDate,
    bool clearChequeDate = false,
    ChequeStatus? chequeStatus,
    bool clearChequeStatus = false,
    String? description,
    List<String>? imagePaths,
  }) {
    return CollectionPlus(
      id: id,
      allocations: allocations ?? this.allocations,
      party: party ?? this.party,
      amount: amount ?? this.amount,
      receivedDate: receivedDate ?? this.receivedDate,
      paymentMode: paymentMode ?? this.paymentMode,
      bankName: clearBankName ? null : (bankName ?? this.bankName),
      chequeNumber:
          clearChequeNumber ? null : (chequeNumber ?? this.chequeNumber),
      chequeDate: clearChequeDate ? null : (chequeDate ?? this.chequeDate),
      chequeStatus:
          clearChequeStatus ? null : (chequeStatus ?? this.chequeStatus),
      description: description ?? this.description,
      imagePaths: imagePaths ?? this.imagePaths,
      createdAt: createdAt,
    );
  }
}
