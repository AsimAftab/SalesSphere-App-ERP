import 'package:sales_sphere_erp/features/catalog/domain/product.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product_category.dart';

/// Domain-side contract for catalog reads. The concrete implementation
/// (wire DTO ↔ domain mapping) lives in
/// `data/repositories/catalog_repository_impl.dart`.
///
/// Both reads return the full catalogue (the impl pages through the
/// cursor) so the catalog UI can keep its existing client-side search +
/// category filtering. The product list is small enough that fetching it
/// whole matches the old mock behaviour.
abstract class CatalogRepository {
  /// All ACTIVE products. Pass [categoryId] to narrow server-side; the
  /// page also filters locally so this is optional.
  Future<List<Product>> getProducts({String? categoryId});

  /// All ACTIVE categories, each carrying its `itemCount`.
  Future<List<ProductCategory>> getCategories();
}
