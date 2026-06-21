import 'package:sales_sphere_erp/features/orders/domain/order_line_item.dart';
import 'package:sales_sphere_erp/features/orders/domain/tax_option.dart';

/// Shared order pricing maths. Mixed into both the live
/// `OrderDraftData` and the saved `Order` so the breakdown shown in
/// the builder, the saved record, and the history rows all agree.
///
/// Flow: per-line discounts are folded into [OrderLineItem.subtotal],
/// then an optional overall discount and a tax line apply to the whole
/// order.
mixin OrderTotals {
  List<OrderLineItem> get items;
  double get overallDiscountPercent;
  TaxOption get tax;

  /// Sum of every line's discounted subtotal.
  double get itemsSubtotal =>
      items.fold(0, (sum, item) => sum + item.subtotal);

  /// Amount removed by the order-wide discount.
  double get overallDiscountAmount =>
      itemsSubtotal * overallDiscountPercent / 100;

  /// Subtotal the tax is charged on (after the overall discount).
  double get taxableBase => itemsSubtotal - overallDiscountAmount;

  /// Tax charged on [taxableBase] at the selected rate.
  double get taxAmount => taxableBase * tax.rate / 100;

  /// Final payable total.
  double get grandTotal => taxableBase + taxAmount;
}
