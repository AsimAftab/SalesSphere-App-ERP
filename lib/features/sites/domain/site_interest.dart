import 'package:flutter/foundation.dart' show immutable;

import 'package:sales_sphere_erp/shared/domain/interest.dart';

/// Site-level point-of-contact: a name + phone pair captured inside
/// the interest sheet's third step (entered via "Next: Contacts" from
/// the brands view). `==` / `hashCode` use both fields so equal
/// contacts dedupe inside `Set` / `List` ops.
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

/// Sites variant of [Interest]. Carries the same (category, brand)
/// identity as the base — equality and hashing fall through to the
/// parent so a `SiteInterest(c, b, [...])` interchanges cleanly with
/// `Interest(c, b)` inside selection sets — but adds a `contacts` list
/// for the (category → contacts) link the sites form needs to capture.
///
/// All `SiteInterest` entries that share a category typically carry
/// the same contacts list (the picker copies the active category's
/// working contacts onto every selected entry of that category on
/// each commit), so callers reading contacts off any one entry get a
/// representative view of the category's contacts.
class SiteInterest extends Interest {
  const SiteInterest({
    required super.category,
    required super.brand,
    this.contacts = const <SiteContact>[],
  });

  final List<SiteContact> contacts;
}
