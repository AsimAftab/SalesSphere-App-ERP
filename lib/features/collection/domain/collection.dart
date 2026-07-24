import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_allocation.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';

/// UI-facing Collection model — one payment received from a party, optionally
/// **allocated across specific invoices**, oldest-first.
///
/// Allocation is optional: a receipt with no invoices selected is a legal
/// on-account advance, and [allocations] comes back empty for it. The module
/// ships on every plan; only posting to the ledger is accounting-only, and the
/// app never posts.
///
/// Two independent axes of state, easy to confuse:
///
///  * [status] — where the receipt sits in the **ledger**. Always starts
///    `DRAFT`; an accountant posts it from the web, which writes the voucher
///    and drops the customer's outstanding balance.
///  * [syncPending] / [syncError] — whether the **device** has handed the row
///    to the server yet. Nothing to do with accounting.
class Collection {
  const Collection({
    required this.id,
    required this.allocations,
    required this.party,
    required this.amount,
    required this.receivedDate,
    required this.paymentMode,
    required this.createdAt,
    this.collectionNo = '',
    this.status = CollectionStatus.draft,
    this.bankName,
    this.chequeNumber,
    this.chequeDate,
    this.chequeStatus,
    this.description = '',
    this.imagePaths = const <String>[],
    this.imageUrls = const <String>[],
    this.createdByName,
    this.syncPending = false,
    this.syncError,
  });

  final String id;

  /// Server-assigned receipt number (`RCPT-82-0001`). Empty while the create
  /// is still queued — the server hasn't numbered it yet.
  final String collectionNo;

  /// How [amount] was split across the party's outstanding invoices,
  /// oldest-first (FIFO).
  ///
  /// **This is the server's answer, not the client's proposal.** The app sends
  /// the selected invoice ids and an amount; the server re-runs FIFO against
  /// live balances and returns this. The on-screen preview is a courtesy — if
  /// a balance moved while the rep was offline, the booked split is whatever
  /// comes back here, and a receipt that no longer fits is refused outright.
  ///
  /// Empty for a pure on-account advance, and for a row still sitting in the
  /// outbox that the server hasn't allocated yet.
  final List<CollectionAllocation> allocations;

  /// The party the payment was collected from. Denormalised so the list card
  /// renders without resolving the allocations.
  final CollectionParty party;

  /// Amount received in NPR. The server stays authoritative on the arithmetic.
  final double amount;

  /// The day the payment was received (date-only in intent).
  final DateTime receivedDate;

  final PaymentMode paymentMode;

  /// Where the receipt sits in the ledger lifecycle. See the class doc — this
  /// is *not* a sync state.
  final CollectionStatus status;

  /// Bank the money moved through. Present only for cheque / bank transfer.
  /// Free text — the catalogue is a suggestion list, not an enum.
  final String? bankName;

  final String? chequeNumber;
  final DateTime? chequeDate;

  /// Clearing state of the cheque. `pending → deposited → cleared`, or
  /// `bounced` from either. Both end states are terminal.
  ///
  /// On a posted receipt this moves real money: clearing writes a contra
  /// voucher, and bouncing writes a reversal that cancels the receipt and
  /// **restores the invoices' outstanding balances**.
  final ChequeStatus? chequeStatus;

  final String description;

  /// Local files picked in the form and not yet uploaded. **Form-only** —
  /// never populated from the network or drift.
  final List<String> imagePaths;

  /// Payment-proof images already stored server-side, in slot order. Max two.
  final List<String> imageUrls;

  /// Display name of the rep who collected the money.
  final String? createdByName;

  /// True while a queued mutation for this row hasn't been confirmed.
  final bool syncPending;

  /// The server's own rejection copy once the sync drain gives up. For this
  /// module that is typically the coverage-short message — a receipt allocated
  /// offline against a balance that has since moved.
  final String? syncError;

  final DateTime createdAt;

  /// True once the server has issued a receipt number.
  bool get hasServerIdentity => collectionNo.isNotEmpty;

  /// The server refuses `PATCH` / `DELETE` on anything but a draft, and a row
  /// still in flight has no server id to address.
  bool get isEditable => status.isEditable && !syncPending;

  /// The invoice ids this receipt settled — what the edit flow resends so the
  /// server can re-derive the split.
  List<String> get invoiceIds =>
      allocations.map((a) => a.invoiceId).toList(growable: false);

  /// The part of [amount] sitting on account rather than against an invoice.
  ///
  /// Mirrors the wire's `unallocatedAmount` exactly — same subtraction, same
  /// floor at zero, same 2-decimal rounding — but recomputed from [amount] and
  /// [allocations] instead of stored, so a row read from the offline cache
  /// reports the same figure as one straight off the network.
  ///
  /// Non-zero means the receipt carries an advance: either the rep recorded one
  /// deliberately, or the payment overshot the invoices it settled.
  double get unallocatedAmount {
    final allocated = allocations.fold<double>(0, (sum, a) => sum + a.amount);
    final remainder = amount - allocated;
    return remainder > 0 ? double.parse(remainder.toStringAsFixed(2)) : 0;
  }

  /// True when this receipt is carrying money on account.
  bool get hasAdvance => unallocatedAmount > 0;

  /// Document numbers this payment settled, for the list / detail cards:
  /// `ORD-2026-0006` for one invoice, `ORD-2026-0006 +1 more` when the payment
  /// spilled across several.
  String get invoiceSummary {
    if (allocations.isEmpty) return '';
    final first = allocations.first.invoiceNumber;
    if (allocations.length == 1) return first;
    return '$first +${allocations.length - 1} more';
  }

  /// Convenience copy used by the edit flow. The `clear*` flags null out the
  /// bank / cheque fields when switching to a payment mode that no longer
  /// needs them — the server renormalises the whole payment block on `PATCH`,
  /// so the client must send the cleared shape it expects.
  Collection copyWith({
    String? id,
    String? collectionNo,
    List<CollectionAllocation>? allocations,
    CollectionParty? party,
    double? amount,
    DateTime? receivedDate,
    PaymentMode? paymentMode,
    CollectionStatus? status,
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
    List<String>? imageUrls,
    String? createdByName,
    bool? syncPending,
    String? syncError,
    bool clearSyncError = false,
  }) {
    return Collection(
      id: id ?? this.id,
      collectionNo: collectionNo ?? this.collectionNo,
      allocations: allocations ?? this.allocations,
      party: party ?? this.party,
      amount: amount ?? this.amount,
      receivedDate: receivedDate ?? this.receivedDate,
      paymentMode: paymentMode ?? this.paymentMode,
      status: status ?? this.status,
      bankName: clearBankName ? null : (bankName ?? this.bankName),
      chequeNumber: clearChequeNumber
          ? null
          : (chequeNumber ?? this.chequeNumber),
      chequeDate: clearChequeDate ? null : (chequeDate ?? this.chequeDate),
      chequeStatus: clearChequeStatus
          ? null
          : (chequeStatus ?? this.chequeStatus),
      description: description ?? this.description,
      imagePaths: imagePaths ?? this.imagePaths,
      imageUrls: imageUrls ?? this.imageUrls,
      createdByName: createdByName ?? this.createdByName,
      syncPending: syncPending ?? this.syncPending,
      syncError: clearSyncError ? null : (syncError ?? this.syncError),
      createdAt: createdAt,
    );
  }
}
