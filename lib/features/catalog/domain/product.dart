/// UI-facing catalog product.
///
/// Plain immutable class backing the mock-data catalog — there is no
/// products API / drift table yet. Follows the same trajectory as
/// `Note` (`features/notes/domain/note.dart`): promote to a freezed
/// entity once the backend + persistence land.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.categoryId,
    required this.price,
    required this.stock,
    this.imageUrl,
    this.isActive = true,
  });

  final String id;
  final String name;

  /// Stock-keeping unit / serial number. Used as a secondary search key.
  final String sku;

  /// Id of the `ProductCategory` this product belongs to.
  final String categoryId;

  /// Unit price in NPR.
  final double price;

  /// Units on hand. `0` renders the card as "Out of Stock".
  final int stock;

  /// Remote image URL. `null` for mock data → the card falls back to
  /// colour-coded initials.
  final String? imageUrl;

  final bool isActive;
}
