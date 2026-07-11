import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
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
/// **There is no `status` here, and that is deliberate.** A plain Collection is
/// a pure CRM / field-ops record: it says a rep collected money, and nothing
/// else. It never posts to a ledger, emits no voucher, and has no
/// DRAFT/POSTED lifecycle — so it is *always* editable. Everything
/// ledger-backed lives in `CollectionPlus`.
///
/// The only state it carries is [syncPending] / [syncError]: whether the device
/// has managed to hand the row to the server yet. That is device state, not
/// accounting state.
class Collection {
  const Collection({
    required this.id,
    required this.party,
    required this.amount,
    required this.receivedDate,
    required this.paymentMode,
    required this.createdAt,
    this.collectionNo = '',
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

  /// Bank the money moved through. Present only for cheque / bank
  /// transfer ([PaymentModeX.requiresBank]); `null` otherwise. Free text —
  /// the bank catalogue is a suggestion list, not an enum.
  final String? bankName;

  /// Cheque number — present only for a cheque collection.
  final String? chequeNumber;

  /// Date written on the cheque — present only for a cheque collection.
  final DateTime? chequeDate;

  /// Clearing state of the cheque — present only for a cheque collection.
  /// Moves `pending → deposited → cleared`, or to `bounced` from either. Both
  /// end states are terminal.
  ///
  /// **Metadata only on a plain Collection.** It records what the cheque did in
  /// the real world and writes no voucher; no money moves. (On Collection Plus
  /// the same transitions drive real PDC accounting.) One consequence the rep
  /// needs to know: a bounced receipt stops counting towards collection
  /// targets.
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

  /// A plain Collection has no posted ledger entry to protect, so the server
  /// allows edit and delete at any time. The only thing that blocks the edit
  /// button is a row still queued in the outbox — it has no server id to
  /// address yet.
  bool get isEditable => !syncPending;

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
