/// Wire DTO for a catalog product, matching `GET /products`. Hand-written
/// (the backend publishes the OpenAPI but these features map wire → domain
/// by hand, mirroring `features/notes/data/dto`).
///
/// Only the fields the mobile catalog consumes are decoded; the backend
/// DTO also carries ledger refs, HSN, inventory-master ids, etc. that the
/// app doesn't render. `price` is the non-null selling rate (server emits
/// `"0"` when `defaultSaleRate` is unset); `stockOnHand` is the computed
/// available whole-unit balance.
class ProductDto {
  const ProductDto({
    required this.id,
    required this.name,
    required this.price,
    required this.stockOnHand,
    required this.isActive,
    this.sku,
    this.categoryId,
    this.imageUrl,
  });

  factory ProductDto.fromJson(Map<String, dynamic> json) => ProductDto(
    id: json['id'] as String,
    name: json['name'] as String,
    // `price` is a non-null decimal string ("1250.00"); guard anyway.
    price: _toDouble(json['price']),
    stockOnHand: (json['stockOnHand'] as num?)?.toInt() ?? 0,
    isActive: (json['isActive'] as bool?) ?? true,
    sku: json['sku'] as String?,
    categoryId: json['categoryId'] as String?,
    imageUrl: json['imageUrl'] as String?,
  );

  final String id;
  final String name;
  final double price;
  final int stockOnHand;
  final bool isActive;
  final String? sku;
  final String? categoryId;
  final String? imageUrl;

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

/// One page of `GET /products` — the decoded `items` plus the cursor to
/// the next page (`null` when the server reports `hasMore == false`).
class ProductsPageDto {
  const ProductsPageDto({required this.items, this.nextCursor});

  final List<ProductDto> items;
  final String? nextCursor;
}
