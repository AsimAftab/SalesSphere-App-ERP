import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/catalog/data/catalog_mock_data.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product_category.dart';

part 'catalog_providers.g.dart';

/// Mock product catalogue. Synchronous — no API/drift yet (design-only
/// port). Swap the body for a repository read when the products feature
/// is wired up.
@riverpod
List<Product> catalogProducts(Ref ref) => kMockProducts;

/// Mock category list backing the chip row + the category-selection grid.
@riverpod
List<ProductCategory> catalogCategories(Ref ref) => kMockCategories;

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
