import 'package:drift/drift.dart';

/// Offline read cache for both collection modules.
///
/// `kind` discriminates the two features so one table, one DAO and one sync
/// handler serve both — the wire shapes are identical apart from Collection
/// Plus's invoice allocations, which live in [CollectionAllocations]. The two
/// features stay separate above this layer (separate APIs, repositories,
/// providers and screens), matching the backend's two modules; sharing the
/// cache just avoids writing the same table twice.
///
///  * `onAccount` → `/collections`   — no invoice link. Every plan.
///  * `allocated` → `/collection-plus` — FIFO-split across invoices.
///                                       ACCOUNTING plans only.
enum CollectionKind { onAccount, allocated }

@DataClassName('CollectionRow')
class Collections extends Table {
  /// Server id, or `local_<uuid>` while the create is still in the outbox.
  TextColumn get id => text()();

  TextColumn get kind => textEnum<CollectionKind>()();

  /// Server-assigned receipt number (`RCPT-82-0001`). Empty until the server
  /// has numbered the row, i.e. for anything still queued offline.
  TextColumn get collectionNo => text().withDefault(const Constant(''))();

  /// Flattened from the wire's `customer { id, name, address, ownerName }`.
  TextColumn get customerId => text()();
  TextColumn get customerName => text()();
  TextColumn get customerAddress => text().nullable()();
  TextColumn get customerOwnerName => text().nullable()();

  /// NPR. The wire carries money as a decimal string; we hold a double here
  /// and let the server stay authoritative on the arithmetic.
  RealColumn get amount => real()();

  DateTimeColumn get receivedDate => dateTime()();
  TextColumn get receivedDateBs => text().withDefault(const Constant(''))();

  /// Wire enum strings — `CASH | CHEQUE | BANK_TRANSFER | QR_PAY`. Stored raw
  /// so the cache is a faithful mirror; the repository maps to domain enums.
  TextColumn get paymentMode => text()();

  /// Free text, not an FK — the picker allows a bank outside the catalogue.
  TextColumn get bankName => text().nullable()();
  TextColumn get chequeNumber => text().nullable()();
  DateTimeColumn get chequeDate => dateTime().nullable()();

  /// `PENDING | DEPOSITED | CLEARED | BOUNCED`. Null unless cheque.
  TextColumn get chequeStatus => text().nullable()();

  TextColumn get description => text().nullable()();

  /// `DRAFT | POSTED | CANCELLED`. Distinct from [syncPending] — DRAFT means
  /// "not committed to a ledger", which is the permanent resting state for a
  /// CRM-only org. It is not an error and not a pending-sync marker.
  TextColumn get status => text()();

  TextColumn get voucherId => text().nullable()();

  /// The rep who collected. Two columns, not one: the list filter sends the
  /// id, the card renders the name.
  TextColumn get createdById => text().nullable()();
  TextColumn get createdByName => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  /// Comma-free JSON array of the embedded `images[]` (`imageNumber` +
  /// `imageUrl`). Small and read-only; a child table would buy nothing.
  TextColumn get imagesJson => text().withDefault(const Constant('[]'))();

  /// True while an outbox-queued mutation hasn't yet been confirmed by the
  /// server. The list card surfaces this with an orange `cloud_off` badge.
  /// Reset to false in the sync handler's onSuccess transaction.
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();

  /// Populated when the sync drain dead-letters this row (4xx, max retries).
  /// The card flips to a red `error_outline` badge while this is non-null.
  ///
  /// This is the server-authoritative rejection surface: a receipt allocated
  /// offline against a now-stale balance comes back 422 with the server's
  /// coverage message, which lands here verbatim for the rep to act on.
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// One invoice slice of a Collection Plus receipt. Empty for `onAccount`
/// rows.
///
/// The split is **computed and owned by the server** — the client sends
/// `invoiceIds` + an amount and receives the authoritative allocation back.
/// These rows are a cache of that answer, never a local calculation.
@DataClassName('CollectionAllocationRow')
class CollectionAllocations extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// FK to [Collections.id]. Carries the `local_<uuid>` id while queued, and
  /// is rewritten when the sync handler swaps in the server id.
  TextColumn get collectionId => text()();

  TextColumn get invoiceId => text()();
  TextColumn get invoiceNumber => text()();
  RealColumn get amount => real()();

  @override
  List<String> get customConstraints => <String>[
    'UNIQUE (collection_id, invoice_id)',
  ];
}
