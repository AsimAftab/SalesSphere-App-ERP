import 'package:flutter/foundation.dart' show immutable;

/// Catalogue of interest categories with their brand options. Used by
/// prospects + sites as the backing data for the interest picker.
///
/// Wrapping the raw `Map<String, List<String>>` shape in a domain
/// entity stops the collection shape from leaking across the
/// repository boundary. Adding metadata later (ids, ordering, sync
/// state) won't break callers because they go through the entity's
/// API instead of poking at the underlying map.
@immutable
class InterestCatalogue {
  /// Stores an unmodifiable view of the supplied [categories] so the
  /// `@immutable` contract holds even if the caller mutates their copy
  /// of the list after construction.
  InterestCatalogue({required List<InterestCategory> categories})
      : categories = List<InterestCategory>.unmodifiable(categories);

  factory InterestCatalogue.empty() => _empty;

  /// Build from the raw `category → brands` map shape used by today's
  /// in-memory APIs. Useful at the data → domain mapping boundary;
  /// once the backend ships a real catalogue endpoint this constructor
  /// goes away in favour of the wire-DTO mapping.
  factory InterestCatalogue.fromMap(Map<String, List<String>> map) =>
      InterestCatalogue(
        categories: <InterestCategory>[
          for (final entry in map.entries)
            InterestCategory(name: entry.key, brands: entry.value),
        ],
      );

  static final InterestCatalogue _empty =
      InterestCatalogue(categories: const <InterestCategory>[]);

  final List<InterestCategory> categories;

  bool get isEmpty => categories.isEmpty;
  bool get isNotEmpty => categories.isNotEmpty;

  /// Brand list for a category name; empty when the category isn't in
  /// the catalogue.
  List<String> brandsFor(String categoryName) {
    for (final c in categories) {
      if (c.name == categoryName) return c.brands;
    }
    return const <String>[];
  }
}

/// One category in an [InterestCatalogue]: a display name and the list
/// of brand options the user can pick under it.
@immutable
class InterestCategory {
  /// Stores an unmodifiable view of the supplied [brands] so the
  /// `@immutable` contract holds even if the caller mutates their copy
  /// of the list after construction.
  InterestCategory({required this.name, required List<String> brands})
      : brands = List<String>.unmodifiable(brands);

  final String name;
  final List<String> brands;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InterestCategory &&
          other.name == name &&
          _listEquals(other.brands, brands));

  @override
  int get hashCode => Object.hash(name, Object.hashAll(brands));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
