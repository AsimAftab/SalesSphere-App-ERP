/// Wire DTO for a catalog category, matching `GET /product-categories`.
/// `itemCount` is the server-computed count of ACTIVE products assigned to
/// the category (drives the selection tile's "N items" badge).
class ProductCategoryDto {
  const ProductCategoryDto({
    required this.id,
    required this.name,
    required this.itemCount,
  });

  factory ProductCategoryDto.fromJson(Map<String, dynamic> json) =>
      ProductCategoryDto(
        id: json['id'] as String,
        name: json['name'] as String,
        itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String name;
  final int itemCount;
}

/// One page of `GET /product-categories`.
class ProductCategoriesPageDto {
  const ProductCategoriesPageDto({required this.items, this.nextCursor});

  final List<ProductCategoryDto> items;
  final String? nextCursor;
}
