import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product_category.dart';

// Re-export the repository provider so consumers (controllers, tests) can
// depend on the contract surface without importing from `data/`.
export 'package:sales_sphere_erp/features/catalog/data/repositories/catalog_repository_impl.dart'
    show catalogRepositoryProvider;

part 'catalog_providers.g.dart';

/// Live product catalogue from `GET /products`. Async — the catalog page
/// paints a loading state, then filters the result client-side (search +
/// category chip). The repository pages through to the full ACTIVE list.
@riverpod
Future<List<Product>> catalogProducts(Ref ref) =>
    ref.watch(catalogRepositoryProvider).getProducts();

/// Live category list from `GET /product-categories`, each carrying its
/// `itemCount`. Backs the chip row + the category-selection grid.
@riverpod
Future<List<ProductCategory>> catalogCategories(Ref ref) =>
    ref.watch(catalogRepositoryProvider).getCategories();

/// Selected category filter, shared by the chip row and the
/// category-selection screen so they stay in sync. `null` means "All".
@riverpod
class SelectedCategory extends _$SelectedCategory {
  @override
  String? build() => null;

  // Kept as a method (not a setter) to read consistently with the cart
  // notifier's add/decrement at Riverpod call sites.
  // ignore: use_setters_to_change_properties
  void select(String? id) => state = id;
}

/// In-memory cart: product id → quantity. Mirrors v1's
/// `orderControllerProvider` — purely local visual state, no checkout
/// or backend. `keepAlive` so the cart survives the Catalog→Order tab
/// switch: the order builder reads it on re-entry to merge the picked
/// products into the draft.
@Riverpod(keepAlive: true)
class Cart extends _$Cart {
  @override
  Map<String, int> build() => const <String, int>{};

  void add(String productId) {
    final next = Map<String, int>.from(state);
    next[productId] = (next[productId] ?? 0) + 1;
    state = next;
  }

  void decrement(String productId) {
    final current = state[productId] ?? 0;
    if (current <= 0) return;
    final next = Map<String, int>.from(state);
    if (current == 1) {
      next.remove(productId);
    } else {
      next[productId] = current - 1;
    }
    state = next;
  }

  void clear() => state = const <String, int>{};
}
