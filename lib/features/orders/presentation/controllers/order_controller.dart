import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/orders/domain/order.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_line_item.dart';
import 'package:sales_sphere_erp/features/orders/presentation/providers/order_providers.dart';

part 'order_controller.g.dart';

/// Routes order / estimate create actions from the builder into the
/// in-memory store. Reads stay on [orderHistoryProvider].
///
/// Mock-only: there's no repository / network yet, so `_create` snapshots
/// the current draft, stamps an id + number + `createdAt`, prepends it to
/// the history list, then resets the draft. When a backend lands this
/// gains a repository dependency and the body becomes a
/// `repo.createOrder(draft)` call.
@riverpod
class OrderController extends _$OrderController {
  @override
  void build() {}

  Future<Order> createOrder() => _create(OrderKind.order);

  Future<Order> createEstimate() => _create(OrderKind.estimate);

  /// Removes a saved estimate from the in-memory history. Mock-only;
  /// gains a `repo.deleteOrder(id)` call when a backend lands.
  void deleteEstimate(String id) =>
      ref.read(orderHistoryProvider.notifier).removeLocal(id);

  /// Converts an [estimate] into a committed order with the chosen
  /// [deliveryDate]. Stamps a fresh `ORD-` number + id, prepends the new
  /// order to the history and drops the source estimate, then returns
  /// the created order. Mock-only.
  Future<Order> convertToOrder(
    Order estimate,
    DateTime deliveryDate,
  ) async {
    final now = DateTime.now();
    final history = ref.read(orderHistoryProvider).value ?? const <Order>[];
    final number = _formatNumber(
      'ORD',
      now.year,
      _nextSequence(history, OrderKind.order),
    );

    final order = Order(
      id: 'inv_${now.microsecondsSinceEpoch}',
      number: number,
      kind: OrderKind.order,
      status: OrderStatus.pending,
      party: estimate.party,
      deliveryDate: deliveryDate,
      items: List<OrderLineItem>.unmodifiable(estimate.items),
      overallDiscountPercent: estimate.overallDiscountPercent,
      tax: estimate.tax,
      createdAt: now,
    );

    ref.read(orderHistoryProvider.notifier)
      ..prependLocal(order)
      ..removeLocal(estimate.id);
    return order;
  }

  Future<Order> _create(OrderKind kind) async {
    final draft = ref.read(orderDraftProvider);
    final now = DateTime.now();
    final prefix = kind == OrderKind.order ? 'ORD' : 'EST';
    final history = ref.read(orderHistoryProvider).value ?? const <Order>[];
    final number =
        _formatNumber(prefix, now.year, _nextSequence(history, kind));

    final order = Order(
      id: '${prefix.toLowerCase()}_${now.microsecondsSinceEpoch}',
      number: number,
      kind: kind,
      status: OrderStatus.pending,
      party: draft.party,
      deliveryDate: draft.deliveryDate,
      items: List<OrderLineItem>.unmodifiable(draft.items),
      overallDiscountPercent: draft.overallDiscountPercent,
      tax: draft.tax,
      createdAt: now,
    );

    ref.read(orderHistoryProvider.notifier).prependLocal(order);
    ref.read(orderDraftProvider.notifier).reset();
    return order;
  }

  /// Formats a document number as `PREFIX-YEAR-NNNN`, e.g.
  /// `ORD-2026-0001` / `EST-2026-0003`. The sequence is zero-padded to
  /// four digits.
  String _formatNumber(String prefix, int year, int sequence) =>
      '$prefix-$year-${sequence.toString().padLeft(4, '0')}';

  /// Next sequence number for [kind]: one past the highest existing
  /// trailing `-NNNN` segment (so it never collides with the seed
  /// numbers). Starts at 1 when there are none yet.
  int _nextSequence(List<Order> history, OrderKind kind) {
    var maxSeq = 0;
    for (final order in history) {
      if (order.kind != kind) continue;
      final seq = int.tryParse(order.number.split('-').last);
      if (seq != null && seq > maxSeq) maxSeq = seq;
    }
    return maxSeq + 1;
  }
}
