import 'package:flutter/foundation.dart';

/// Lightweight party reference used by the optional "Select party"
/// picker on the expense-claim form. The real parties feature is
/// backend-backed; while the expense feature is mock-only it carries
/// its own slim party shape so the picker doesn't depend on the live
/// parties data layer.
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
