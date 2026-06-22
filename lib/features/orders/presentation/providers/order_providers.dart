import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/catalog/domain/product.dart';
import 'package:sales_sphere_erp/features/orders/data/repositories/order_repository_impl.dart';
import 'package:sales_sphere_erp/features/orders/data/tax_options.dart';
import 'package:sales_sphere_erp/features/orders/domain/order.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_draft_data.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_line_item.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_organization.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_party.dart';
import 'package:sales_sphere_erp/features/orders/domain/tax_option.dart';
import 'package:sales_sphere_erp/features/parties/presentation/providers/parties_providers.dart';

// Re-export the repository provider so consumers (the controller, tests)
// can depend on the contract surface without importing from `data/`.
export 'package:sales_sphere_erp/features/orders/data/repositories/order_repository_impl.dart'
    show orderRepositoryProvider;

part 'order_providers.g.dart';

/// Page size pulled for the order party picker. The picker searches the
/// fetched set client-side, so one generous page covers a field rep's book.
const int _kPartyPickerPageSize = 100;

/// Parties offered in the searchable "Select party" sheet. Sourced from the
/// live customers list (`GET /customers`) and mapped to the slim
/// [OrderParty] the picker needs (carrying `ownerName` for the order's
/// auto-filled owner field).
@riverpod
Future<List<OrderParty>> orderParties(Ref ref) async {
  final page = await ref
      .watch(partiesRepositoryProvider)
      .getPartiesPage(limit: _kPartyPickerPageSize);
  return page.items
      .map(
        (p) => OrderParty(
          id: p.id,
          name: p.name,
          ownerName: p.ownerName,
          address: p.address,
          panVat: p.panVat,
          phone: p.phone,
        ),
      )
      .toList(growable: false);
}

/// Tax lines offered in the order's tax picker (No Tax / VAT 13%).
@riverpod
List<TaxOption> taxOptions(Ref ref) => kTaxOptions;

/// The selling organisation rendered as the "From" party on the order
/// detail page, from `GET /organizations/print-profile`.
@riverpod
Future<OrderOrganization> orderOrganization(Ref ref) =>
    ref.watch(orderRepositoryProvider).getPrintProfile();

/// The live order-builder draft. `keepAlive` so it survives navigation
/// reliably (the Add-Item catalog round-trip, the History push). It is
/// reset to empty after a successful create, and when the user leaves the
/// `/order` zone for another tab (handled by the router redirect in
/// `app_router.dart`).
@Riverpod(keepAlive: true)
class OrderDraft extends _$OrderDraft {
  @override
  OrderDraftData build() => OrderDraftData.initial(kDefaultTaxOption);

  void selectParty(OrderParty party) => state = state.copyWith(party: party);

  void clearParty() => state = state.copyWith(clearParty: true);

  void setDeliveryDate(DateTime date) =>
      state = state.copyWith(deliveryDate: date);

  /// Merge picked products into the draft at quantity 1. Products already
  /// present are left untouched so any edits are preserved; only new ids
  /// become fresh lines.
  void addProducts(List<Product> products) {
    final existing = <String>{for (final line in state.items) line.productId};
    final additions = products
        .where((p) => !existing.contains(p.id))
        .map(OrderLineItem.fromProduct)
        .toList(growable: false);
    if (additions.isEmpty) return;
    state = state.copyWith(
      items: <OrderLineItem>[...state.items, ...additions],
    );
  }

  /// Merge a catalog cart (productId → quantity) into the draft. New
  /// products become lines at the cart quantity (capped to stock);
  /// products already on the order are left untouched (edit their
  /// quantity on the line instead).
  void addFromCart(Map<String, int> cart, List<Product> products) {
    final existing = <String>{for (final line in state.items) line.productId};
    final additions = <OrderLineItem>[];
    for (final entry in cart.entries) {
      if (existing.contains(entry.key)) continue;
      Product? product;
      for (final p in products) {
        if (p.id == entry.key) {
          product = p;
          break;
        }
      }
      if (product == null || product.stock <= 0) continue;
      additions.add(
        OrderLineItem.fromProduct(product, quantity: entry.value),
      );
    }
    if (additions.isEmpty) return;
    state = state.copyWith(
      items: <OrderLineItem>[...state.items, ...additions],
    );
  }

  void removeItem(String productId) => state = state.copyWith(
    items: state.items
        .where((line) => line.productId != productId)
        .toList(growable: false),
  );

  void updateQuantity(String productId, int quantity) =>
      _patch(productId, (line) {
        final max = line.availableStock < 1 ? 1 : line.availableStock;
        final clamped = quantity < 1 ? 1 : (quantity > max ? max : quantity);
        return line.copyWith(quantity: clamped);
      });

  void updateBasePrice(String productId, double basePrice) => _patch(
    productId,
    (line) => line.copyWith(basePrice: basePrice < 0 ? 0 : basePrice),
  );

  /// Sets the base price implied by a discount off the listed price —
  /// the inverse of [OrderLineItem.discountPercent]. Keeps base price
  /// and discount as two views of the same value.
  void updateDiscountPercent(String productId, double discountPercent) =>
      _patch(productId, (line) {
        final pct = discountPercent.clamp(0, 100);
        return line.copyWith(basePrice: line.listedPrice * (1 - pct / 100));
      });

  void setOverallDiscountPercent(double percent) =>
      state = state.copyWith(overallDiscountPercent: percent.clamp(0, 100));

  void setTax(TaxOption tax) => state = state.copyWith(tax: tax);

  void reset() => state = OrderDraftData.initial(kDefaultTaxOption);

  void _patch(
    String productId,
    OrderLineItem Function(OrderLineItem) update,
  ) {
    final index = state.items.indexWhere((line) => line.productId == productId);
    if (index == -1) return;
    final next = <OrderLineItem>[...state.items];
    next[index] = update(next[index]);
    state = state.copyWith(items: next);
  }
}

/// In-memory list of saved orders + estimates, hydrated from the backend
/// (`GET /invoices` + `GET /estimates`, merged newest-first). The history
/// screen watches this; the controller prepends/removes rows after a
/// successful write. `keepAlive` so created records persist across
/// navigation within the order zone.
@Riverpod(keepAlive: true)
class OrderHistory extends _$OrderHistory {
  @override
  Future<List<Order>> build() => ref.read(orderRepositoryProvider).getHistory();

  /// Insert [order] at the head of the list. Called by the controller
  /// after a successful create.
  void prependLocal(Order order) {
    final current = state.value ?? const <Order>[];
    if (current.any((i) => i.id == order.id)) return;
    state = AsyncValue<List<Order>>.data(<Order>[order, ...current]);
  }

  /// Drop the record with [id] from the list. Backs the estimate delete
  /// action (and the convert-to-order flow, which removes the source
  /// estimate after creating the order).
  void removeLocal(String id) {
    final current = state.value ?? const <Order>[];
    state = AsyncValue<List<Order>>.data(
      current.where((i) => i.id != id).toList(growable: false),
    );
  }

  /// Pull-to-refresh / header refresh — re-fetch from the backend.
  Future<void> refresh() async {
    state = const AsyncValue<List<Order>>.loading();
    state = await AsyncValue.guard(
      () => ref.read(orderRepositoryProvider).getHistory(),
    );
  }
}

/// Resolves a single record by id from the loaded history. Returns `null`
/// when the list hasn't resolved yet or the id isn't present (the detail
/// page passes the record via `extra` to avoid the former).
@riverpod
Order? orderById(Ref ref, String id) {
  final all = ref.watch(orderHistoryProvider).value ?? const <Order>[];
  for (final order in all) {
    if (order.id == id) return order;
  }
  return null;
}
