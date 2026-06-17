/// UI-facing catalog category.
///
/// Plain immutable class backing the mock-data catalog (see `Product`).
/// Kept presentation-free: the per-category accent colour + icon live in
/// `presentation/widgets/category_visuals.dart`, keyed by [name].
class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    required this.itemCount,
  });

  final String id;
  final String name;

  /// Number of products in this category — shown on the selection tile.
  final int itemCount;
}
