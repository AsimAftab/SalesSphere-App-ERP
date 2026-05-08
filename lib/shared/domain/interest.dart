import 'package:flutter/foundation.dart' show immutable;

/// A category + brand pair surfaced by the shared interest picker.
/// `==` and `hashCode` are overridden so equal interests dedupe in
/// `Set` / `List` operations the picker performs internally.
///
/// Lives in the shared-domain layer so feature-domain models like
/// `SiteInterest` and prospect-side imports can depend on it without
/// reaching into the widget layer.
@immutable
class Interest {
  const Interest({required this.category, required this.brand});

  final String category;
  final String brand;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Interest && other.category == category && other.brand == brand);

  @override
  int get hashCode => Object.hash(category, brand);

  @override
  String toString() => '$category · $brand';
}
