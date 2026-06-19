import 'package:flutter/foundation.dart';

/// Lightweight party reference used by the searchable party picker on the
/// invoice builder. The real parties feature is backend-backed; while
/// invoice is mock-only it carries its own slim party shape so the picker
/// doesn't depend on the live parties data layer. Carries [ownerName] so
/// the invoice's owner field can auto-fill when a party is picked.
///
/// Equality is by [id] so a selected option can be matched back to its
/// list entry inside the picker regardless of instance identity.
@immutable
class InvoiceParty {
  const InvoiceParty({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.address,
    this.panVat = '',
    this.phone = '',
  });

  final String id;
  final String name;

  /// Proprietor / contact name — auto-filled into the invoice's
  /// read-only "Owner name" field when this party is selected.
  final String ownerName;
  final String address;

  /// PAN / VAT registration number — shown on the invoice detail's
  /// "Bill to" card. Empty when the party has none on file.
  final String panVat;

  /// Contact phone — shown on the invoice detail's "Bill to" card.
  /// Empty when not on file.
  final String phone;

  @override
  bool operator ==(Object other) => other is InvoiceParty && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
