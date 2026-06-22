import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/catalog/data/catalog_api.dart';
import 'package:sales_sphere_erp/features/catalog/data/dto/product_category_dto.dart';
import 'package:sales_sphere_erp/features/catalog/data/dto/product_dto.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product_category.dart';
import 'package:sales_sphere_erp/features/catalog/domain/repositories/catalog_repository.dart';

/// Anti-corruption layer between the catalog wire DTOs and the UI-facing
/// domain models. Pages through the cursor to assemble the full list (the
/// catalog is small and the UI filters client-side).
class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({required CatalogApi api}) : _api = api;

  final CatalogApi _api;

  /// Safety cap on the page loop so a misbehaving cursor can't spin
  /// forever. 20 × 100 = 2000 products is far beyond any field catalogue.
  static const _maxPages = 20;

  @override
  Future<List<Product>> getProducts({String? categoryId}) async {
    final all = <Product>[];
    String? cursor;
    for (var page = 0; page < _maxPages; page++) {
      final dto = await _api.listProducts(cursor: cursor, categoryId: categoryId);
      all.addAll(dto.items.map(_toProduct));
      cursor = dto.nextCursor;
      if (cursor == null) break;
    }
    return all;
  }

  @override
  Future<List<ProductCategory>> getCategories() async {
    final all = <ProductCategory>[];
    String? cursor;
    for (var page = 0; page < _maxPages; page++) {
      final dto = await _api.listCategories(cursor: cursor);
      all.addAll(dto.items.map(_toCategory));
      cursor = dto.nextCursor;
      if (cursor == null) break;
    }
    return all;
  }

  Product _toProduct(ProductDto dto) => Product(
    id: dto.id,
    name: dto.name,
    sku: dto.sku ?? '',
    // The catalog groups by category id; the server returns the primary
    // assignment (first category) or null. Fall back to an empty string so
    // the (single-category) filter still partitions cleanly.
    categoryId: dto.categoryId ?? '',
    price: dto.price,
    stock: dto.stockOnHand,
    imageUrl: dto.imageUrl,
    isActive: dto.isActive,
  );

  ProductCategory _toCategory(ProductCategoryDto dto) => ProductCategory(
    id: dto.id,
    name: dto.name,
    itemCount: dto.itemCount,
  );
}

/// Exposes the abstract type so consumers depend on the contract, not the
/// impl. Tests override this with a fake `CatalogRepository`.
final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepositoryImpl(api: ref.watch(catalogApiProvider));
});
