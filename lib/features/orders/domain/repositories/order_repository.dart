import 'package:sales_sphere_erp/features/orders/domain/order.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_draft_data.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_organization.dart';

/// Domain-side contract for orders + estimates. The concrete
/// implementation (wire DTO ↔ domain mapping, the invoice/estimate split,
/// the convert chain) lives in `data/repositories/order_repository_impl.dart`.
///
/// A mobile "order" is a backend invoice and an "estimate" is a backend
/// estimate; both surface here as the unified [Order] domain entity keyed
/// by [Order.kind].
abstract class OrderRepository {
  /// All orders + estimates, merged and sorted newest-first — backs the
  /// two History tabs.
  Future<List<Order>> getHistory();

  /// Commits the current builder [draft] as an order (`POST /invoices`).
  /// The draft's delivery date is required.
  Future<Order> createOrder(OrderDraftData draft);

  /// Commits the current builder [draft] as an estimate (`POST /estimates`).
  Future<Order> createEstimate(OrderDraftData draft);

  /// Converts [estimate] into a committed order with [deliveryDate]
  /// (`POST /estimates/{id}/convert` then fetches the new invoice).
  Future<Order> convertToOrder(Order estimate, DateTime deliveryDate);

  /// Deletes a not-yet-converted estimate (`DELETE /estimates/{id}`).
  Future<void> deleteEstimate(String id);

  /// The selling org / branch "From" profile for the detail page.
  Future<OrderOrganization> getPrintProfile();
}
