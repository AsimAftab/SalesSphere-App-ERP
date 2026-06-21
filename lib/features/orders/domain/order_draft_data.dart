import 'package:flutter/foundation.dart';

import 'package:sales_sphere_erp/features/orders/domain/order_line_item.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_party.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_totals.dart';
import 'package:sales_sphere_erp/features/orders/domain/tax_option.dart';

/// Immutable snapshot of the order builder's working state. Held by
/// the `OrderDraft` notifier and rebuilt on every edit; the UI reads
/// the [OrderTotals] getters for the live pricing breakdown.
@immutable
class OrderDraftData with OrderTotals {
  const OrderDraftData({
    required this.tax,
    this.party,
    this.deliveryDate,
    this.items = const <OrderLineItem>[],
    this.overallDiscountPercent = 0,
  });

  /// A fresh, empty draft with [defaultTax] preselected.
  factory OrderDraftData.initial(TaxOption defaultTax) =>
      OrderDraftData(tax: defaultTax);

  final OrderParty? party;
  final DateTime? deliveryDate;
  @override
  final List<OrderLineItem> items;
  @override
  final double overallDiscountPercent;
  @override
  final TaxOption tax;

  bool get isEmpty => items.isEmpty;

  OrderDraftData copyWith({
    OrderParty? party,
    DateTime? deliveryDate,
    List<OrderLineItem>? items,
    double? overallDiscountPercent,
    TaxOption? tax,
    bool clearParty = false,
    bool clearDeliveryDate = false,
  }) {
    return OrderDraftData(
      party: clearParty ? null : (party ?? this.party),
      deliveryDate:
          clearDeliveryDate ? null : (deliveryDate ?? this.deliveryDate),
      items: items ?? this.items,
      overallDiscountPercent:
          overallDiscountPercent ?? this.overallDiscountPercent,
      tax: tax ?? this.tax,
    );
  }
}
