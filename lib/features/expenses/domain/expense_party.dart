import 'package:flutter/foundation.dart';

/// Lightweight party reference used by the optional "Select party"
/// picker on the expense-claim form. A claim's optional `partyId` is a
/// real Customer id; on read the backend embeds `party { id, companyName }`
/// for the label, which the repository maps into this slim shape (the
/// [address] is only populated when the option comes from the live
/// customers list feeding the picker — it's empty for a hydrated claim).
///
/// Equality is by [id] so a selected option can be matched back to its
/// list entry inside the picker regardless of instance identity.
@immutable
class ExpenseParty {
  const ExpenseParty({
    required this.id,
    required this.name,
    required this.address,
  });

  final String id;
  final String name;
  final String address;

  @override
  bool operator ==(Object other) =>
      other is ExpenseParty && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
