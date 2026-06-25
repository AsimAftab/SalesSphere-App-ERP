import 'package:flutter/foundation.dart';

/// Lightweight party reference used by the "Select party" picker on the
/// collection form. The real parties feature is backend-backed; while
/// the collection feature is mock-only it carries its own slim party
/// shape so the picker doesn't depend on the live parties data layer.
///
/// Equality is by [id] so a selected option can be matched back to its
/// list entry inside the picker regardless of instance identity.
@immutable
class CollectionParty {
  const CollectionParty({
    required this.id,
    required this.name,
    required this.address,
    this.ownerName = '',
  });

  final String id;
  final String name;
  final String address;

  /// Optional contact / proprietor name shown as supporting detail.
  final String ownerName;

  @override
  bool operator ==(Object other) =>
      other is CollectionParty && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
