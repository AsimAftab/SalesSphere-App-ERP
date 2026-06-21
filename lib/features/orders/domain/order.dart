import 'package:flutter/foundation.dart';

import 'package:sales_sphere_erp/features/orders/domain/order_line_item.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_party.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_totals.dart';
import 'package:sales_sphere_erp/features/orders/domain/tax_option.dart';

/// Whether a saved record is a committed order or a non-binding
/// estimate/quotation. Drives the two History tabs and the document
/// number prefix (`ORD-` / `EST-`).
enum OrderKind { order, estimate }

String orderKindLabel(OrderKind kind) =>
    kind == OrderKind.order ? 'Order' : 'Estimate';

/// Fulfilment state of a saved order / estimate. New records start
/// [pending]; the rest model the delivery workflow. Drives the status
/// badge on the history cards and the detail page.
enum OrderStatus { pending, inProgress, inTransit, completed, rejected }

String orderStatusLabel(OrderStatus status) => switch (status) {
      OrderStatus.pending => 'Pending',
      OrderStatus.inProgress => 'In Progress',
      OrderStatus.inTransit => 'In Transit',
      OrderStatus.completed => 'Completed',
      OrderStatus.rejected => 'Rejected',
    };

/// A saved order or estimate. Built from an `OrderDraftData`
/// snapshot at create time and stored in the in-memory history list.
/// Reuses [OrderTotals] so history rows show the same grand total the
/// builder did.
@immutable
class Order with OrderTotals {
  const Order({
    required this.id,
    required this.number,
    required this.kind,
    required this.status,
    required this.items,
    required this.overallDiscountPercent,
    required this.tax,
    required this.createdAt,
    this.party,
    this.deliveryDate,
  });

  final String id;

  /// Human-facing document number, e.g. `ORD-1007` / `EST-1003`.
  final String number;
  final OrderKind kind;
  final OrderStatus status;
  final OrderParty? party;
  final DateTime? deliveryDate;
  @override
  final List<OrderLineItem> items;
  @override
  final double overallDiscountPercent;
  @override
  final TaxOption tax;
  final DateTime createdAt;
}
