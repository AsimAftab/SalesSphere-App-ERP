import 'package:flutter/foundation.dart';

/// Lightweight party reference used by the searchable party picker on the
/// order builder. The real parties feature is backend-backed; while
/// order is mock-only it carries its own slim party shape so the picker
/// doesn't depend on the live parties data layer. Carries [ownerName] so
/// the order's owner field can auto-fill when a party is picked.
///
/// Equality is by [id] so a selected option can be matched back to its
/// list entry inside the picker regardless of instance identity.
@immutable
class OrderParty {
  const OrderParty({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.address,
    this.panVat = '',
    this.phone = '',
  });

  final String id;
  final String name;

  /// Proprietor / contact name — auto-filled into the order's
  /// read-only "Owner name" field when this party is selected.
  final String ownerName;
  final String address;

  /// PAN / VAT registration number — shown on the order detail's
  /// "Bill to" card. Empty when the party has none on file.
  final String panVat;

  /// Contact phone — shown on the order detail's "Bill to" card.
  /// Empty when not on file.
  final String phone;

  @override
  bool operator ==(Object other) => other is OrderParty && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
