import 'package:sales_sphere_erp/features/collection/data/dto/collection_dto.dart';
import 'package:sales_sphere_erp/features/collection/data/dto/wire_codecs.dart';

/// Wire DTO for a Collection Plus receipt — `Collection` plus the three things
/// only a ledger-backed receipt has.
///
/// The split matters. A plain Collection is a CRM record: money came in, that's
/// all. Collection Plus is an **accounting document** — it allocates across
/// invoices, posts a voucher, and can be cancelled with a reversal. So:
///
///  * [status] — `DRAFT | POSTED | CANCELLED`. Editable only while DRAFT.
///  * [voucherId] — set once posted.
///  * [allocations] — the server's FIFO split across invoices.
///
/// `/collections` returns none of these. Sharing one DTO across both endpoints
/// is what made `status` a required field the server never sent.
class CollectionPlusDto extends CollectionDto {
  const CollectionPlusDto({
    required super.id,
    required super.collectionNo,
    required super.customer,
    required super.amount,
    required super.receivedDate,
    required super.paymentMode,
    required super.images,
    required super.createdAt,
    required this.status,
    super.receivedDateBS,
    super.bankName,
    super.chequeNumber,
    super.chequeDate,
    super.chequeStatus,
    super.description,
    super.createdBy,
    super.clientRequestId,
    this.voucherId,
    this.allocations = const <CollectionAllocationDto>[],
  });

  factory CollectionPlusDto.fromJson(Map<String, dynamic> json) =>
      CollectionPlusDto(
        id: json['id'] as String,
        collectionNo: (json['collectionNo'] as String?) ?? '',
        customer: CollectionCustomerDto.fromJson(
          json['customer'] as Map<String, dynamic>,
        ),
        amount: parseMoney(json['amount']),
        receivedDate: parseWireDate(json['receivedDate'] as String),
        receivedDateBS: (json['receivedDateBS'] as String?) ?? '',
        paymentMode: json['paymentMode'] as String,
        bankName: json['bankName'] as String?,
        chequeNumber: json['chequeNumber'] as String?,
        chequeDate: json['chequeDate'] == null
            ? null
            : parseWireDate(json['chequeDate'] as String),
        chequeStatus: json['chequeStatus'] as String?,
        description: json['description'] as String?,
        images: parseCollectionImages(json['images']),
        status: json['status'] as String,
        voucherId: json['voucherId'] as String?,
        createdBy: json['createdBy'] == null
            ? null
            : CollectionCreatedByDto.fromJson(
                json['createdBy'] as Map<String, dynamic>,
              ),
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        allocations: _parseAllocations(json['allocations']),
      );

  /// `DRAFT | POSTED | CANCELLED` on the wire.
  final String status;

  /// Set once posted to the ledger; null while DRAFT.
  final String? voucherId;

  /// How the receipt was split across invoices, oldest-first.
  ///
  /// **The server computes this and owns it.** The client sends `invoiceIds` +
  /// an amount and gets the authoritative allocation back; it never sends a
  /// split of its own. Empty only for a row still queued in the outbox, which
  /// the server hasn't allocated yet.
  final List<CollectionAllocationDto> allocations;

  /// Create body. Carries the invoices the rep **selected** — never a split.
  @override
  Map<String, dynamic> toCreateJson({List<String>? invoiceIds}) =>
      <String, dynamic>{
        ...super.toCreateJson(),
        if (invoiceIds != null) 'invoiceIds': invoiceIds,
      };

  /// Update body. Resending the selection lets the server release this
  /// receipt's own allocations and re-run FIFO over the new amount.
  @override
  Map<String, dynamic> toUpdateJson({List<String>? invoiceIds}) =>
      <String, dynamic>{
        ...super.toUpdateJson(),
        if (invoiceIds != null) 'invoiceIds': invoiceIds,
      };

  @override
  CollectionPlusDto withId(String newId) => CollectionPlusDto(
    id: newId,
    collectionNo: collectionNo,
    customer: customer,
    amount: amount,
    receivedDate: receivedDate,
    receivedDateBS: receivedDateBS,
    paymentMode: paymentMode,
    bankName: bankName,
    chequeNumber: chequeNumber,
    chequeDate: chequeDate,
    chequeStatus: chequeStatus,
    description: description,
    images: images,
    status: status,
    voucherId: voucherId,
    createdBy: createdBy,
    createdAt: createdAt,
    clientRequestId: clientRequestId,
    allocations: allocations,
  );

  static List<CollectionAllocationDto> _parseAllocations(Object? raw) {
    if (raw is! List) return const <CollectionAllocationDto>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CollectionAllocationDto.fromJson)
        .toList(growable: false);
  }
}

/// One invoice slice of a Collection Plus receipt, as returned by the server.
///
/// Read-only: the server's answer, not the client's proposal. The on-screen
/// FIFO preview is a courtesy; the booked split is whatever comes back here.
class CollectionAllocationDto {
  const CollectionAllocationDto({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.amount,
  });

  factory CollectionAllocationDto.fromJson(Map<String, dynamic> json) =>
      CollectionAllocationDto(
        invoiceId: json['invoiceId'] as String,
        invoiceNumber: (json['invoiceNumber'] as String?) ?? '',
        amount: parseMoney(json['amount']),
      );

  final String invoiceId;

  /// Falls back to the order number server-side when the invoice hasn't been
  /// numbered yet, so this is always renderable.
  final String invoiceNumber;

  final double amount;
}

/// An invoice with money still owed on it, from
/// `GET /collection-plus/parties/{partyId}/outstanding`.
///
/// Returned **oldest-first with fully-paid rows dropped** — the same order the
/// server's FIFO uses, so the preview can consume it as-is.
///
/// Only POSTED invoices are collectible: an unposted order isn't a receivable
/// yet, so it won't appear. An empty list means "nothing to settle", not a bug.
class OutstandingInvoiceDto {
  const OutstandingInvoiceDto({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.totalAmount,
    required this.paid,
    required this.outstanding,
    this.lastPaidOn,
    this.priorPayments = const <PriorPaymentDto>[],
  });

  factory OutstandingInvoiceDto.fromJson(Map<String, dynamic> json) =>
      OutstandingInvoiceDto(
        invoiceId: json['invoiceId'] as String,
        invoiceNumber: (json['invoiceNumber'] as String?) ?? '',
        invoiceDate: parseWireDate(json['invoiceDate'] as String),
        totalAmount: parseMoney(json['totalAmount']),
        paid: parseMoney(json['paid']),
        outstanding: parseMoney(json['outstanding']),
        lastPaidOn: json['lastPaidOn'] == null
            ? null
            : parseWireDate(json['lastPaidOn'] as String),
        priorPayments: _parsePriorPayments(json['priorPayments']),
      );

  final String invoiceId;
  final String invoiceNumber;

  /// The FIFO sort key. Server order is `invoiceDate` ascending, ties broken by
  /// `invoiceNumber` ascending — match it exactly or the preview shows a split
  /// that isn't the one that gets booked.
  final DateTime invoiceDate;

  final double totalAmount;
  final double paid;

  /// `totalAmount - paid`, clamped at zero. Derived server-side on every read —
  /// never cached, which is how a bounced cheque restores a balance with no
  /// compensating row.
  final double outstanding;

  final DateTime? lastPaidOn;

  /// The individual allocations that make up [paid], oldest-first — the same
  /// filtered rows [paid] and [lastPaidOn] are derived from server-side (this
  /// receipt's own allocations excluded, capped at its Received Date). Lets the
  /// UI list each prior payment separately instead of one lumped figure.
  ///
  /// Empty for older receipts recorded before the server started emitting the
  /// field, in which case the UI falls back to the grouped [paid] display.
  final List<PriorPaymentDto> priorPayments;

  static List<PriorPaymentDto> _parsePriorPayments(Object? raw) {
    if (raw is! List) return const <PriorPaymentDto>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PriorPaymentDto.fromJson)
        .toList(growable: false);
  }
}

/// One prior allocation booked against an invoice, from an invoice's
/// `priorPayments` array. Read-only history — `{ amount, receivedDate }` is the
/// entire wire shape (no collection number is returned).
class PriorPaymentDto {
  const PriorPaymentDto({required this.amount, required this.receivedDate});

  factory PriorPaymentDto.fromJson(Map<String, dynamic> json) =>
      PriorPaymentDto(
        amount: parseMoney(json['amount']),
        receivedDate: parseWireDate(json['receivedDate'] as String),
      );

  final double amount;
  final DateTime receivedDate;
}
