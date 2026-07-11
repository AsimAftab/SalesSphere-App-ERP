import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';

/// UI-facing collection model — one recorded payment received from a
/// party. Decoupled from the wire DTO so a backend rename doesn't ripple
/// into widgets.
///
/// This is a plain **on-account** receipt: the money is collected against the
/// *party* as a whole, not booked against any specific invoice. (Collection
/// Plus is the invoice-allocated sibling.) The bank / cheque fields are only
/// populated when [paymentMode] calls for them ([PaymentModeX.requiresBank] /
/// [PaymentModeX.requiresChequeDetails]).
///
/// Two independent axes of state, easy to confuse:
///
///  * [status] — where the receipt sits in the **ledger**. Always starts
///    `DRAFT`; an accountant posts it from the web. A CRM-only org has no
///    ledger and never grants `collections:post`, so its receipts stay
///    `DRAFT` forever. That is normal, not broken.
///  * [syncPending] / [syncError] — whether the **device** has managed to
///    hand the row to the server yet. Nothing to do with accounting.
class Collection {
  const Collection({
    required this.id,
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
  /// is still queued in the outbox — the server hasn't numbered it yet, so the
  /// UI shows the sync badge instead.
  final String collectionNo;

  /// The party the payment was collected from.
  final CollectionParty party;

  /// Amount received in NPR. The wire carries money as a decimal string; the
  /// server stays authoritative on the arithmetic.
  final double amount;

  /// The day the payment was received (date-only in intent).
  final DateTime receivedDate;

  final PaymentMode paymentMode;

  /// Where the receipt sits in the ledger lifecycle. See the class doc — this
  /// is *not* a sync state.
  final CollectionStatus status;

  /// Bank the money moved through. Present only for cheque / bank
  /// transfer ([PaymentModeX.requiresBank]); `null` otherwise. Free text —
  /// the bank catalogue is a suggestion list, not an enum.
  final String? bankName;

  /// Cheque number — present only for a cheque collection.
  final String? chequeNumber;

  /// Date written on the cheque — present only for a cheque collection.
  final DateTime? chequeDate;

  /// Clearing state of the cheque — present only for a cheque collection.
  /// Moves `PENDING → DEPOSITED → CLEARED`, or to `BOUNCED` from either.
  /// Both end states are terminal.
  final ChequeStatus? chequeStatus;

  /// Optional free-text note describing the collection.
  final String description;

  /// Local files picked in the form and not yet uploaded. **Form-only** —
  /// never populated from the network or drift.
  final List<String> imagePaths;

  /// Payment-proof images already stored server-side (Cloudinary URLs), in
  /// slot order. Max two.
  final List<String> imageUrls;

  /// Display name of the rep who collected the money. Null on rows migrated
  /// from the backend's old `Payment` table, which carried no creator.
  final String? createdByName;

  /// True while a queued mutation for this row hasn't been confirmed by the
  /// server. Renders an orange `cloud_off` badge.
  final bool syncPending;

  /// The server's own rejection copy, once the sync drain gives up on this
  /// row. Renders a red badge. For Collection Plus this is typically the
  /// coverage-short message — a receipt allocated offline against a balance
  /// that has since moved.
  final String? syncError;

  /// When the collection row was created. Drives list ordering.
  final DateTime createdAt;

  /// True once the server has issued a receipt number, i.e. the row exists
  /// remotely. Local-only rows render the number slot as the sync badge.
  bool get hasServerIdentity => collectionNo.isNotEmpty;

  /// The server refuses `PATCH` / `DELETE` on anything but a draft, and a row
  /// still in flight has no server id to address. Both gate the edit button.
  bool get isEditable => status.isEditable && !syncPending;

  /// Convenience copy used by the edit flow. The `clear*` flags null
  /// out the bank / cheque fields when switching to a payment mode that
  /// no longer needs them — the server renormalises the whole payment block
  /// on `PATCH`, so the client must send the cleared shape it expects.
  Collection copyWith({
    String? id,
    String? collectionNo,
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
