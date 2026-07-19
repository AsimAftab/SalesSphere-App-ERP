import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';

/// Single source of truth for `PartyRow -> Party`. Shared by the
/// repository's network-fetch paths (`PartiesRepositoryImpl`) and the
/// presentation layer's reactive drift stream
/// (`partiesListVisibleProvider`) so a new column only needs mapping
/// in one place.
Party partyRowToDomain(PartyRow row) {
  return Party(
    id: row.id,
    name: row.name,
    address: row.address ?? '',
    ownerName: row.ownerName ?? '',
    alias: row.alias,
    panVat: row.panNo ?? '',
    phone: row.phone ?? '',
    email: row.email,
    dateJoined: row.dateJoined,
    partyType: row.partyType,
    notes: row.notes,
    latitude: row.latitude,
    longitude: row.longitude,
    status: row.status,
    creditLimitAmount: row.creditLimitAmount,
    syncPending: row.syncPending,
    syncError: row.syncError,
  );
}
