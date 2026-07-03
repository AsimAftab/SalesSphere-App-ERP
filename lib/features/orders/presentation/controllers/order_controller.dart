import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/core/services/downloads_saver.dart';
import 'package:sales_sphere_erp/features/orders/domain/order.dart';
import 'package:sales_sphere_erp/features/orders/presentation/providers/order_providers.dart';
import 'package:sales_sphere_erp/features/orders/presentation/services/order_pdf_builder.dart';

part 'order_controller.g.dart';

/// Routes order / estimate write actions from the builder + history into
/// the `OrderRepository` (backend invoices / estimates), then reconciles
/// the result into [orderHistoryProvider] so the UI refreshes. Reads stay
/// on the reactive providers.
///
/// This controller is autoDispose and nothing watches it (its state is
/// `void`), so it is disposed during the network round-trip of a write.
/// Every method therefore resolves its keep-alive collaborators
/// ([orderHistoryProvider] / [orderDraftProvider] / the repository)
/// *before* awaiting — touching `ref` after the await would throw
/// "Ref used after dispose" and surface as a bogus write failure even
/// though the server accepted the request.
@riverpod
class OrderController extends _$OrderController {
  @override
  void build() {}

  /// Creates an order from the current draft (`POST /invoices`), prepends
  /// it to history and resets the draft. The page validates that a party,
  /// items and a delivery date are present before calling this.
  Future<Order> createOrder() async {
    final draft = ref.read(orderDraftProvider);
    final history = ref.read(orderHistoryProvider.notifier);
    final draftNotifier = ref.read(orderDraftProvider.notifier);
    final repository = ref.read(orderRepositoryProvider);
    final order = await repository.createOrder(draft);
    history.prependLocal(order);
    draftNotifier.reset();
    return order;
  }

  /// Creates an estimate from the current draft (`POST /estimates`).
  Future<Order> createEstimate() async {
    final draft = ref.read(orderDraftProvider);
    final history = ref.read(orderHistoryProvider.notifier);
    final draftNotifier = ref.read(orderDraftProvider.notifier);
    final repository = ref.read(orderRepositoryProvider);
    final order = await repository.createEstimate(draft);
    history.prependLocal(order);
    draftNotifier.reset();
    return order;
  }

  /// Deletes a not-yet-converted estimate (`DELETE /estimates/{id}`), then
  /// drops it from history. Rethrows on failure so the caller can surface it.
  Future<void> deleteEstimate(String id) async {
    final history = ref.read(orderHistoryProvider.notifier);
    final repository = ref.read(orderRepositoryProvider);
    await repository.deleteEstimate(id);
    history.removeLocal(id);
  }

  /// Renders [order] to a PDF and saves it into the device's public
  /// Downloads folder (Play-compliant MediaStore write on Android 10+),
  /// returning the saved file's local path so the caller can offer to open
  /// it. Rethrows on failure so the page can surface it.
  ///
  /// Collaborators are resolved *before* the first await, per the class doc.
  /// The org is read straight from the (keep-alive) repository rather than
  /// via `orderOrganizationProvider.future`: from a history card nothing is
  /// watching that autoDispose provider, so its future could be orphaned
  /// when it disposes mid-flight and the export would hang. The repository
  /// call always completes — the same pattern the write methods above use.
  Future<String> downloadPdf(Order order) async {
    final saver = ref.read(downloadsSaverProvider);
    final repository = ref.read(orderRepositoryProvider);
    final organization = await repository.getPrintProfile();
    final bytes = await OrderPdfBuilder.build(
      order: order,
      organization: organization,
    );
    return saver.save(fileName: '${order.number}.pdf', bytes: bytes);
  }

  /// Converts [estimate] into a committed order with [deliveryDate],
  /// prepends the new order and drops the source estimate from history.
  Future<Order> convertToOrder(Order estimate, DateTime deliveryDate) async {
    final history = ref.read(orderHistoryProvider.notifier);
    final repository = ref.read(orderRepositoryProvider);
    final order = await repository.convertToOrder(estimate, deliveryDate);
    history
      ..prependLocal(order)
      ..removeLocal(estimate.id);
    return order;
  }
}
