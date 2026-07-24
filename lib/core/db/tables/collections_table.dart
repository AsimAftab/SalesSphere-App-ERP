import 'package:drift/drift.dart';

/// Offline read cache for collections.
///
/// `kind` is a **legacy discriminator**. It dates from when the backend had two
/// collection modules and this one table served both; those merged into a
/// single `/collections` module, so everything written now is [allocated] and
/// [onAccount] is unreachable. The column is kept rather than migrated away
/// because dropping it buys nothing — it costs one text field and quietly
/// partitions any pre-merge rows still sitting in an upgraded install's cache
/// out of the list, which is the behaviour we want.
enum CollectionKind {
  /// Pre-merge rows from the old on-account module. Never written any more.
  onAccount,

  /// Every row written today, allocated or not — a receipt with no invoices is
  /// an on-account advance and still lands here.
  allocated,
}

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

  /// `DRAFT | POSTED | CANCELLED`.
  ///
  /// Nullable only for the legacy `onAccount` rows, which predate the module
  /// merge and carry no ledger lifecycle. Every row written today has one.
  ///
  /// Distinct from [syncPending], which is device state — whether the row has
  /// reached the server at all.
  TextColumn get status => text().nullable()();

  /// Set once the receipt posts to the ledger; null while DRAFT.
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

/// One invoice slice of a receipt. Empty for an on-account advance, and for
/// legacy `onAccount` rows.
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
