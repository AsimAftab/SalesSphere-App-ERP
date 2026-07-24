import 'package:sales_sphere_erp/features/collection/data/dto/wire_codecs.dart';

/// Wire DTO for a collection receipt.
///
/// A receipt is an **accounting document**: it allocates across invoices, posts
/// a voucher, and can be cancelled with a reversal. Hence:
///
///  * [status] — `DRAFT | POSTED | CANCELLED`. Editable only while DRAFT.
///  * [voucherId] — set once posted.
///  * [allocations] — the server's FIFO split across invoices, `[]` for a pure
///    on-account advance.
///
/// The wire also carries `unallocatedAmount` (`amount` minus the allocations,
/// floored at zero, as a 2-decimal string). It is deliberately not a field
/// here: it is exactly derivable from [amount] and [allocations], both of which
/// the drift cache already stores, so `Collection.unallocatedAmount` recomputes
/// it and the offline read agrees with the online one by construction.
class CollectionDto {
  const CollectionDto({
    required this.id,
    required this.collectionNo,
    required this.customer,
    required this.amount,
    required this.receivedDate,
    required this.paymentMode,
    required this.images,
    required this.createdAt,
    required this.status,
    this.receivedDateBS = '',
    this.bankName,
    this.chequeNumber,
    this.chequeDate,
    this.chequeStatus,
    this.description,
    this.createdBy,
    this.clientRequestId,
    this.voucherId,
    this.allocations = const <CollectionAllocationDto>[],
  });

  factory CollectionDto.fromJson(Map<String, dynamic> json) =>
      CollectionDto(
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
        status: json['status'] as String? ?? 'DRAFT',
        voucherId: json['voucherId'] as String?,
        createdBy: json['createdBy'] == null
            ? null
            : CollectionCreatedByDto.fromJson(
                json['createdBy'] as Map<String, dynamic>,
              ),
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        allocations: _parseAllocations(json['allocations']),
      );

  final String id;
  final String collectionNo;
  final CollectionCustomerDto customer;
  final double amount;
  final DateTime receivedDate;
  final String receivedDateBS;
  final String paymentMode;
  final String? bankName;
  final String? chequeNumber;
  final DateTime? chequeDate;
  final String? chequeStatus;
  final String? description;
  final List<CollectionImageDto> images;
  final CollectionCreatedByDto? createdBy;
  final DateTime createdAt;
  final String? clientRequestId;

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
  Map<String, dynamic> toCreateJson({List<String>? invoiceIds}) =>
      <String, dynamic>{
        'customerId': customer.id,
        ...paymentBlockJson(),
        if (clientRequestId != null) 'clientRequestId': clientRequestId,
        if (invoiceIds != null) 'invoiceIds': invoiceIds,
      };

  Map<String, dynamic> toUpdateJson({List<String>? invoiceIds}) =>
      <String, dynamic>{
        ...paymentBlockJson(),
        if (invoiceIds != null) 'invoiceIds': invoiceIds,
      };

  Map<String, dynamic> paymentBlockJson() => <String, dynamic>{
        'amount': amount,
        'receivedDate': dateToWire(receivedDate),
        if (receivedDateBS.isNotEmpty) 'receivedDateBS': receivedDateBS,
        'paymentMode': paymentMode,
        'bankName': bankName,
        'chequeNumber': chequeNumber,
        'chequeDate': chequeDate == null ? null : dateToWire(chequeDate!),
        'chequeStatus': chequeStatus,
        'description': description,
      };

  CollectionDto withId(String newId) => CollectionDto(
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

/// One invoice slice of a receipt, as returned by the server.
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
/// `GET /collections/parties/{partyId}/outstanding`.
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
class CollectionCustomerDto {
    const CollectionCustomerDto({
      required this.id,
      required this.name,
      this.address,
      this.ownerName,
    });
  
    factory CollectionCustomerDto.fromJson(Map<String, dynamic> json) =>
        CollectionCustomerDto(
          id: json['id'] as String,
          name: (json['name'] as String?) ?? '',
          address: json['address'] as String?,
          ownerName: json['ownerName'] as String?,
        );
  
    final String id;
    final String name;
    final String? address;
    final String? ownerName;
  }
  
  /// The rep who recorded the collection (`createdBy { id, name }`).
  ///
  /// Two fields, not one: the list filter sends the **id** (`createdById`) while
  /// the card renders the **name**. The mock used to compare a picked id against
  /// a display name, which could never match.
  class CollectionCreatedByDto {
    const CollectionCreatedByDto({required this.id, required this.name});
  
    factory CollectionCreatedByDto.fromJson(Map<String, dynamic> json) =>
        CollectionCreatedByDto(
          id: json['id'] as String,
          name: (json['name'] as String?) ?? '',
        );
  
    final String id;
    final String name;
  }
  
  /// One payment-proof image slot as embedded in the collection read model.
  ///
  /// 1-indexed, matching the `imageNumber` used by the POST form field and the
  /// DELETE path. (The POST response itself returns a different, 0-indexed
  /// `sortOrder` shape — we ignore that body and refetch the collection.)
  class CollectionImageDto {
    const CollectionImageDto({required this.imageNumber, required this.imageUrl});
  
    factory CollectionImageDto.fromJson(Map<String, dynamic> json) =>
        CollectionImageDto(
          imageNumber: (json['imageNumber'] as num).toInt(),
          imageUrl: json['imageUrl'] as String,
        );
  
    final int imageNumber;
    final String imageUrl;
  }
  
  List<CollectionImageDto> parseCollectionImages(Object? raw) {
    if (raw is! List) return const <CollectionImageDto>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CollectionImageDto.fromJson)
        .toList(growable: false);
  }





