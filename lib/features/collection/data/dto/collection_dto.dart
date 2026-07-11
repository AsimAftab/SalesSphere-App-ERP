import 'package:sales_sphere_erp/features/collection/data/dto/wire_codecs.dart';

/// Wire DTO for a plain (on-account) collection — the read model returned by
/// `/collections`, plus the writable subset emitted by [toCreateJson] /
/// [toUpdateJson]. Hand-written, mirroring the expense-claim / party DTOs.
///
/// ## No `status`, no `voucherId` — deliberately
///
/// A plain Collection is a **pure CRM / field-ops record**: it says a rep
/// collected money, and nothing else. It never posts to a ledger, never emits a
/// voucher, and has no DRAFT/POSTED lifecycle to sit in. Everything
/// ledger-backed lives in Collection Plus, whose [CollectionPlusDto] extends
/// this with `status`, `voucherId` and `allocations`.
///
/// This used to be one shared DTO carrying all three. `/collections` stopped
/// returning them, which made `status` a required field that was never sent —
/// so every read threw.
///
/// Enums stay as raw wire strings here (`CASH`, `PENDING`); the repository maps
/// them to domain enums. That keeps the DTO a faithful mirror of the wire and
/// puts every codec in one place.
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
    this.receivedDateBS = '',
    this.bankName,
    this.chequeNumber,
    this.chequeDate,
    this.chequeStatus,
    this.description,
    this.createdBy,
    this.clientRequestId,
  });

  factory CollectionDto.fromJson(Map<String, dynamic> json) => CollectionDto(
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
    createdBy: json['createdBy'] == null
        ? null
        : CollectionCreatedByDto.fromJson(
            json['createdBy'] as Map<String, dynamic>,
          ),
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String id;

  /// Server-assigned receipt number (`RCPT-82-0001`). Empty only while a create
  /// is still queued in the outbox — the server hasn't numbered it yet.
  final String collectionNo;

  final CollectionCustomerDto customer;

  /// NPR. Parsed from the wire string; sent back as a number. See [parseMoney].
  final double amount;

  /// Calendar day the money was received. Date-only.
  final DateTime receivedDate;

  /// Nepali (Bikram Sambat) rendering of [receivedDate], derived server-side.
  /// The client only ever sends AD.
  final String receivedDateBS;

  /// `CASH | CHEQUE | BANK_TRANSFER | QR_PAY` on the wire.
  final String paymentMode;

  /// Free text — not an FK. The bank catalogue is a suggestion list, and the
  /// picker lets the user type a bank that isn't on it.
  final String? bankName;

  final String? chequeNumber;

  /// May be in the **future** — that's what post-dated means.
  final DateTime? chequeDate;

  /// `PENDING | DEPOSITED | CLEARED | BOUNCED`. Null unless [paymentMode] is
  /// `CHEQUE`.
  ///
  /// On a plain Collection this is **metadata only**: it records what the
  /// cheque did in the real world and writes no voucher. (On Collection Plus
  /// the same transitions do real PDC accounting.)
  final String? chequeStatus;

  final String? description;

  /// Payment proof, max 2 slots. Embedded in the read model — there is no
  /// `GET /collections/{id}/images`.
  final List<CollectionImageDto> images;

  /// The rep who collected the money. Null on rows migrated from the backend's
  /// old `Payment` table, which carried no creator.
  final CollectionCreatedByDto? createdBy;

  final DateTime createdAt;

  /// Offline replay key. Never returned by the server — carried here so the
  /// outbox payload keeps the same key across retries, which is what makes
  /// `POST` idempotent (a replay returns the original row with 200).
  final String? clientRequestId;

  /// Writable subset sent on **create**.
  ///
  /// `amount` goes out as a number (the server coerces to Decimal). Every
  /// payment-block field is emitted unconditionally, including nulls, so
  /// switching payment mode *clears* the stale cheque/bank values rather than
  /// leaving them behind.
  Map<String, dynamic> toCreateJson() => <String, dynamic>{
    'customerId': customer.id,
    ...paymentBlockJson(),
    if (clientRequestId != null) 'clientRequestId': clientRequestId,
  };

  /// Writable subset sent on **update**.
  ///
  /// Deliberately omits `customerId` — a receipt cannot be reassigned to
  /// another party, and the server strips the field anyway.
  Map<String, dynamic> toUpdateJson() => paymentBlockJson();

  /// The full payment block, shared by create and update.
  ///
  /// `PATCH` is **payment-block-atomic** server-side: send `paymentMode` and the
  /// whole bank/cheque block is renormalised (values the new mode doesn't own
  /// are cleared); omit it and the block is frozen. So the full block always
  /// goes, nulls included.
  Map<String, dynamic> paymentBlockJson() => <String, dynamic>{
    'amount': amount,
    'receivedDate': dateToWire(receivedDate),
    'paymentMode': paymentMode,
    'bankName': bankName,
    'chequeNumber': chequeNumber,
    'chequeDate': chequeDate == null ? null : dateToWire(chequeDate!),
    'chequeStatus': chequeStatus,
    'description': description,
  };

  /// Stamp a different id — used by the offline path to swap in a
  /// `local_<uuid>` placeholder before the row is cached in drift.
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
    createdBy: createdBy,
    createdAt: createdAt,
    clientRequestId: clientRequestId,
  );
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
