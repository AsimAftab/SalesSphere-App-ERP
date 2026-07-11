import 'package:flutter/foundation.dart';

/// Lightweight party reference used by the "Select party" picker on the
/// collection form.
///
/// Deliberately slim, and deliberately not `Party`. The rows are mapped from
/// the live customers feature (`partiesListVisibleProvider`), but the picker
/// only needs four fields — and keeping a per-feature shape means the picker
/// doesn't drag in the whole parties data layer. Same pattern as
/// `ExpenseParty`.
///
/// Equality is by [id] so a selected option can be matched back to its
/// list entry inside the picker regardless of instance identity.
@immutable
class CollectionPlusParty {
  const CollectionPlusParty({
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
      other is CollectionPlusParty && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
