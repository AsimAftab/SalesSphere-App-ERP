/// Wire DTO for a collection — the read model returned by `/collections`,
/// plus the writable subset emitted by [toJson]. Hand-written (mirrors the
/// expense-claim / party DTOs).
///
/// Enums stay as raw wire strings here (`CASH`, `PENDING`, `DRAFT`); the
/// repository maps them to the domain enums. That keeps the DTO a faithful
/// mirror of the wire and puts every codec in one place.
///
/// Two wire quirks worth knowing, both verified against `/openapi.json`:
///
///  * **`amount` is asymmetric.** It goes out as a JSON *number* and comes
///    back as a *string* (`"20000.00"`, `Decimal.toFixed(2)`). Same for the
///    allocation / outstanding amounts on Collection Plus.
///  * **Two date formats.** `receivedDate` and `chequeDate` are bare
///    `yyyy-MM-dd` calendar days; `createdAt` / `updatedAt` are full ISO
///    timestamps. Don't run one codec over both.
class CollectionDto {
  const CollectionDto({
    required this.id,
    required this.collectionNo,
    required this.customer,
    required this.amount,
    required this.receivedDate,
    required this.paymentMode,
    required this.status,
    required this.images,
    required this.createdAt,
    this.receivedDateBS = '',
    this.bankName,
    this.chequeNumber,
    this.chequeDate,
    this.chequeStatus,
    this.description,
    this.voucherId,
    this.createdBy,
    this.clientRequestId,
    this.allocations = const <CollectionAllocationDto>[],
  });

  factory CollectionDto.fromJson(Map<String, dynamic> json) => CollectionDto(
    id: json['id'] as String,
    collectionNo: (json['collectionNo'] as String?) ?? '',
    customer: CollectionCustomerDto.fromJson(
      json['customer'] as Map<String, dynamic>,
    ),
    amount: _parseMoney(json['amount']),
    receivedDate: _parseDate(json['receivedDate'] as String),
    receivedDateBS: (json['receivedDateBS'] as String?) ?? '',
    paymentMode: json['paymentMode'] as String,
    bankName: json['bankName'] as String?,
    chequeNumber: json['chequeNumber'] as String?,
    chequeDate: json['chequeDate'] == null
        ? null
        : _parseDate(json['chequeDate'] as String),
    chequeStatus: json['chequeStatus'] as String?,
    description: json['description'] as String?,
    images: _parseImages(json['images']),
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

  final String id;

  /// Server-assigned receipt number (`RCPT-82-0001`). Empty only for a row
  /// still queued in the outbox — the server hasn't numbered it yet.
  final String collectionNo;

  final CollectionCustomerDto customer;

  /// NPR. Parsed from the wire string; sent back as a number.
  final double amount;

  /// Calendar day the money was received. Date-only.
  final DateTime receivedDate;

  /// Nepali (Bikram Sambat) rendering of [receivedDate], derived server-side.
  /// The client only ever sends AD.
  final String receivedDateBS;

  /// `CASH | CHEQUE | BANK_TRANSFER | QR_PAY` on the wire.
  final String paymentMode;

  /// Free text — not an FK. The bank catalogue is a suggestion list and the
  /// picker lets the user type a bank that isn't on it.
  final String? bankName;

  final String? chequeNumber;
  final DateTime? chequeDate;

  /// `PENDING | DEPOSITED | CLEARED | BOUNCED`. Null unless [paymentMode]
  /// is `CHEQUE`.
  final String? chequeStatus;

  final String? description;

  /// Payment proof, max 2 slots. Embedded in the read model — there is no
  /// `GET /collections/{id}/images`.
  final List<CollectionImageDto> images;

  /// `DRAFT | POSTED | CANCELLED` on the wire.
  final String status;

  /// Set once posted to the ledger; null while DRAFT.
  final String? voucherId;

  /// The rep who collected the money. Null on rows migrated from the old
  /// `Payment` table, which carried no creator.
  final CollectionCreatedByDto? createdBy;

  final DateTime createdAt;

  /// Offline replay key. Never returned by the server — it's carried here so
  /// the outbox payload keeps the same key across retries, which is what
  /// makes `POST` idempotent (replay returns 200 + the original row).
  final String? clientRequestId;

  /// Invoice slices of the receipt. **Always empty for a plain `/collections`
  /// row** — an on-account receipt is booked against the party, not an
  /// invoice. Populated only by `/collection-plus`.
  ///
  /// On the wire, `CollectionPlus` is exactly `Collection` + `allocations[]`,
  /// so one DTO serves both endpoints rather than duplicating twenty fields
  /// of parsing that would inevitably drift apart.
  ///
  /// **The server computes this split and owns it.** The client sends
  /// `invoiceIds` + an amount and gets the authoritative allocation back; it
  /// never sends a split of its own.
  final List<CollectionAllocationDto> allocations;

  /// Writable subset sent on **create**.
  ///
  /// `amount` goes out as a number (the server coerces to Decimal). Every
  /// payment-block field is emitted unconditionally, including nulls, so
  /// switching payment mode *clears* the stale cheque/bank values rather than
  /// leaving them behind.
  ///
  /// [invoiceIds] is for the Collection Plus endpoint only, and carries the
  /// invoices the rep *selected* — never a split. The server runs FIFO against
  /// live balances and returns the authoritative `allocations`.
  Map<String, dynamic> toCreateJson({List<String>? invoiceIds}) =>
      <String, dynamic>{
        'customerId': customer.id,
        'amount': amount,
        'receivedDate': _dateToWire(receivedDate),
        'paymentMode': paymentMode,
        'bankName': bankName,
        'chequeNumber': chequeNumber,
        'chequeDate': chequeDate == null ? null : _dateToWire(chequeDate!),
        'chequeStatus': chequeStatus,
        'description': description,
        if (clientRequestId != null) 'clientRequestId': clientRequestId,
        if (invoiceIds != null) 'invoiceIds': invoiceIds,
      };

  /// Writable subset sent on **update**.
  ///
  /// Deliberately omits `customerId` — a receipt cannot be reassigned to
  /// another party, and the server strips the field anyway.
  ///
  /// `PATCH` is **payment-block-atomic** on the server: send `paymentMode`
  /// and the whole bank/cheque block is renormalised (values the new mode
  /// doesn't own are cleared); omit it and the block is frozen. So we always
  /// resend the full block.
  Map<String, dynamic> toUpdateJson({List<String>? invoiceIds}) =>
      <String, dynamic>{
        'amount': amount,
        'receivedDate': _dateToWire(receivedDate),
        'paymentMode': paymentMode,
        'bankName': bankName,
        'chequeNumber': chequeNumber,
        'chequeDate': chequeDate == null ? null : _dateToWire(chequeDate!),
        'chequeStatus': chequeStatus,
        'description': description,
        if (invoiceIds != null) 'invoiceIds': invoiceIds,
      };

  /// Stamp a different id — used by the offline path to swap the server id
  /// for a `local_<uuid>` placeholder before the row is cached in drift.
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

  /// Money arrives as a decimal string (`"20000.00"`). Tolerate a raw number
  /// too — a locally-built draft round-trips through drift without going near
  /// the wire.
  static double _parseMoney(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0;
    return 0;
  }

  static List<CollectionImageDto> _parseImages(Object? raw) {
    if (raw is! List) return const <CollectionImageDto>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CollectionImageDto.fromJson)
        .toList(growable: false);
  }

  static List<CollectionAllocationDto> _parseAllocations(Object? raw) {
    if (raw is! List) return const <CollectionAllocationDto>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CollectionAllocationDto.fromJson)
        .toList(growable: false);
  }

  /// Parse a `yyyy-MM-dd` calendar day into a local-midnight [DateTime] whose
  /// Y/M/D match the server's stored day regardless of device timezone.
  static DateTime _parseDate(String raw) {
    final d = DateTime.parse(raw);
    return DateTime(d.year, d.month, d.day);
  }

  /// Wire format for a calendar day: bare `yyyy-MM-dd`, no timezone to drift.
  static String _dateToWire(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Embedded party label on the read model (`customer { id, name, address,
/// ownerName }`). Note the wire key is `customer`, and the create body takes
/// `customerId` — not `partyId`.
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
/// Two fields, not one: the list filter sends the **id** (`createdById`)
/// while the card renders the **name**. The mock used to compare a picked id
/// against a display name, which could never match.
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

/// One invoice slice of a Collection Plus receipt, as returned by the server.
///
/// Read-only: this is the server's answer, not the client's proposal. The
/// on-screen FIFO preview is a courtesy; the booked split is whatever comes
/// back here.
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
        amount: CollectionDto._parseMoney(json['amount']),
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
/// yet, so it won't appear here. An empty list means "nothing to settle",
/// not a bug.
class OutstandingInvoiceDto {
  const OutstandingInvoiceDto({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.totalAmount,
    required this.paid,
    required this.outstanding,
    this.lastPaidOn,
  });

  factory OutstandingInvoiceDto.fromJson(Map<String, dynamic> json) =>
      OutstandingInvoiceDto(
        invoiceId: json['invoiceId'] as String,
        invoiceNumber: (json['invoiceNumber'] as String?) ?? '',
        invoiceDate: CollectionDto._parseDate(json['invoiceDate'] as String),
        totalAmount: CollectionDto._parseMoney(json['totalAmount']),
        paid: CollectionDto._parseMoney(json['paid']),
        outstanding: CollectionDto._parseMoney(json['outstanding']),
        lastPaidOn: json['lastPaidOn'] == null
            ? null
            : CollectionDto._parseDate(json['lastPaidOn'] as String),
      );

  final String invoiceId;
  final String invoiceNumber;

  /// The FIFO sort key. Server order is `invoiceDate` ascending, ties broken
  /// by `invoiceNumber` ascending — match it exactly or the preview shows a
  /// split that isn't the one that gets booked.
  final DateTime invoiceDate;

  final double totalAmount;
  final double paid;

  /// `totalAmount - paid`, clamped at zero. Derived server-side on every read
  /// — never cached, which is how a bounced cheque restores a balance without
  /// a compensating row.
  final double outstanding;

  final DateTime? lastPaidOn;
}
