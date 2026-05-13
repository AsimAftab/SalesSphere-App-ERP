import 'package:flutter/foundation.dart' show immutable;

/// Secondary point-of-contact at a site — the people who answer the
/// door but aren't the formal owner. Captured via the
/// `SiteContactPicker` field on the site form, with a cap of four
/// contacts per site enforced at the picker level.
///
/// `==` / `hashCode` use both fields so equal contacts dedupe inside
/// `Set` / `List` operations the picker performs internally.
@immutable
class SiteContact {
  const SiteContact({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SiteContact && other.name == name && other.phone == phone);

  @override
  int get hashCode => Object.hash(name, phone);

  @override
  String toString() => '$name ($phone)';
}
