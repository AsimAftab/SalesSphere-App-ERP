/// UI-facing party model. Decoupled from wire DTOs so backend renames
/// don't ripple into widgets.
///
/// Naming asymmetry: the wire calls this field `panNo`; we keep `panVat`
/// here because the form's labels, validators and the existing test
/// corpus all reference that name. The repository mapper does the
/// translation.
///
/// `imagePaths` is form-only state: the add/edit pages let the user
/// attach gallery photos locally. The list/detail pages show icons; the
/// mobile UI never renders fetched image URLs, so this list is always
/// empty for parties that came from the network.
///
/// `syncPending` / `syncError` carry per-row sync state from the
/// mutation outbox. Server-fetched rows always have `syncPending=false`;
/// optimistically-inserted rows (offline writes) start with
/// `syncPending=true` and flip back to false in the sync handler's
/// onSuccess transaction. A non-null `syncError` means the row's
/// queued mutation dead-lettered.
class Party {
  const Party({
    required this.id,
    required this.name,
    required this.address,
    required this.ownerName,
    required this.phone,
    required this.panVat,
    this.alias,
    this.email,
    this.dateJoined,
    this.partyType,
    this.notes,
    this.latitude,
    this.longitude,
    this.imagePaths = const <String>[],
    this.status,
    this.syncPending = false,
    this.syncError,
  });

  final String id;
  final String name;
  final String address;

  /// Required by the form's `Validators.requiredField` / `phone10` /
  /// `panVat` on both add and edit — kept non-nullable here so the form
  /// contract and the domain shape agree.
  final String ownerName;
  final String phone;
  final String panVat;

  /// Alternate display name / short code (e.g. "KT") — optional, used
  /// for picker search parity with Tally.
  final String? alias;

  // Other optional details captured by the add-party form.
  final String? email;
  final DateTime? dateJoined;

  /// Mobile picker-driven categorisation. Backed by the wire
  /// `customerType.name` on read; sent as a flat string on write
  /// (`PartyDto.toJson` flattens it to `customerType: "<name>"` and the
  /// backend auto-upserts the corresponding row).
  final String? partyType;
  final String? notes;
  final double? latitude;
  final double? longitude;

  /// Local file paths from the add/edit form's image picker. Always
  /// empty for parties hydrated from the API or drift cache.
  final List<String> imagePaths;

  /// `ACTIVE` | `INACTIVE`. Server-driven; null only for in-flight form
  /// drafts that haven't been sent yet.
  final String? status;

  /// True while an outbox-queued mutation hasn't yet been confirmed by
  /// the server.
  final bool syncPending;

  /// Last sync failure for this row (dead-letter only). Null when
  /// `syncPending` is true but no failure has occurred yet, or when the
  /// row is server-authoritative.
  final String? syncError;

  Party copyWith({
    bool? syncPending,
    String? syncError,
    bool clearSyncError = false,
  }) {
    return Party(
      id: id,
      name: name,
      address: address,
      ownerName: ownerName,
      phone: phone,
      panVat: panVat,
      alias: alias,
      email: email,
      dateJoined: dateJoined,
      partyType: partyType,
      notes: notes,
      latitude: latitude,
      longitude: longitude,
      imagePaths: imagePaths,
      status: status,
      syncPending: syncPending ?? this.syncPending,
      syncError: clearSyncError ? null : (syncError ?? this.syncError),
    );
  }
}
