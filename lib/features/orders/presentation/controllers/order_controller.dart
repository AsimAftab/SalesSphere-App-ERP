import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/orders/domain/order.dart';
import 'package:sales_sphere_erp/features/orders/presentation/providers/order_providers.dart';

part 'order_controller.g.dart';

/// Routes order / estimate write actions from the builder + history into
/// the `OrderRepository` (backend invoices / estimates), then reconciles
/// the result into [orderHistoryProvider] so the UI refreshes. Reads stay
/// on the reactive providers.
@riverpod
class OrderController extends _$OrderController {
  @override
  void build() {}

  /// Creates an order from the current draft (`POST /invoices`), prepends
  /// it to history and resets the draft. The page validates that a party,
  /// items and a delivery date are present before calling this.
  Future<Order> createOrder() async {
    final draft = ref.read(orderDraftProvider);
    final order = await ref.read(orderRepositoryProvider).createOrder(draft);
    ref.read(orderHistoryProvider.notifier).prependLocal(order);
    ref.read(orderDraftProvider.notifier).reset();
    return order;
  }

  /// Creates an estimate from the current draft (`POST /estimates`).
  Future<Order> createEstimate() async {
    final draft = ref.read(orderDraftProvider);
    final order = await ref.read(orderRepositoryProvider).createEstimate(draft);
    ref.read(orderHistoryProvider.notifier).prependLocal(order);
    ref.read(orderDraftProvider.notifier).reset();
    return order;
  }

  /// Deletes a not-yet-converted estimate (`DELETE /estimates/{id}`), then
  /// drops it from history. Rethrows on failure so the caller can surface it.
  Future<void> deleteEstimate(String id) async {
    await ref.read(orderRepositoryProvider).deleteEstimate(id);
    ref.read(orderHistoryProvider.notifier).removeLocal(id);
  }

  /// Converts [estimate] into a committed order with [deliveryDate],
  /// prepends the new order and drops the source estimate from history.
  Future<Order> convertToOrder(Order estimate, DateTime deliveryDate) async {
    final order = await ref
        .read(orderRepositoryProvider)
        .convertToOrder(estimate, deliveryDate);
    ref.read(orderHistoryProvider.notifier)
      ..prependLocal(order)
      ..removeLocal(estimate.id);
    return order;
  }
}
