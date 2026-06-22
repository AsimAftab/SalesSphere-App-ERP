import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/utils/uuid.dart';
import 'package:sales_sphere_erp/features/orders/data/dto/estimate_dto.dart';
import 'package:sales_sphere_erp/features/orders/data/dto/invoice_dto.dart';
import 'package:sales_sphere_erp/features/orders/data/dto/order_line_item_dto.dart';
import 'package:sales_sphere_erp/features/orders/data/dto/order_party_dto.dart';
import 'package:sales_sphere_erp/features/orders/data/dto/org_print_profile_dto.dart';
import 'package:sales_sphere_erp/features/orders/data/orders_api.dart';
import 'package:sales_sphere_erp/features/orders/data/tax_options.dart';
import 'package:sales_sphere_erp/features/orders/domain/order.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_draft_data.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_line_item.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_organization.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_party.dart';
import 'package:sales_sphere_erp/features/orders/domain/repositories/order_repository.dart';

/// Anti-corruption layer for orders. Splits the unified [Order] domain
/// entity across the backend's invoice (`kind == order`) and estimate
/// (`kind == estimate`) endpoints, maps wire DTOs ↔ domain, and owns the
/// convert chain (convert returns the estimate; we fetch the new invoice).
class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl({required OrdersApi api}) : _api = api;

  final OrdersApi _api;

  /// Page-loop safety cap (× 100/page) — far beyond any field history.
  static const _maxPages = 20;

  @override
  Future<List<Order>> getHistory() async {
    final invoices = <InvoiceDto>[];
    String? cursor;
    for (var page = 0; page < _maxPages; page++) {
      final dto = await _api.listInvoices(cursor: cursor);
      invoices.addAll(dto.items);
      cursor = dto.nextCursor;
      if (cursor == null) break;
    }

    final estimates = <EstimateDto>[];
    cursor = null;
    for (var page = 0; page < _maxPages; page++) {
      final dto = await _api.listEstimates(cursor: cursor);
      estimates.addAll(dto.items);
      cursor = dto.nextCursor;
      if (cursor == null) break;
    }

    final orders = <Order>[
      ...invoices.map(_invoiceToOrder),
      // An accepted estimate has become an order — hide it from the
      // Estimates tab so the converted document isn't shown twice.
      ...estimates
          .where((e) => e.convertedInvoiceId == null)
          .map(_estimateToOrder),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  @override
  Future<Order> createOrder(OrderDraftData draft) async {
    final dto = await _api.createInvoice(
      _createBody(draft, deliveryDate: draft.deliveryDate),
    );
    return _invoiceToOrder(dto);
  }

  @override
  Future<Order> createEstimate(OrderDraftData draft) async {
    final dto = await _api.createEstimate(_createBody(draft));
    return _estimateToOrder(dto);
  }

  @override
  Future<Order> convertToOrder(Order estimate, DateTime deliveryDate) async {
    final converted = await _api.convertEstimate(estimate.id, <String, dynamic>{
      'expectedDeliveryDate': deliveryDate.toIso8601String(),
    });
    final invoiceId = converted.convertedInvoiceId;
    if (invoiceId == null) {
      throw StateError('Convert did not return a linked invoice id');
    }
    final invoice = await _api.getInvoice(invoiceId);
    return _invoiceToOrder(invoice);
  }

  @override
  Future<void> deleteEstimate(String id) => _api.deleteEstimate(id);

  @override
  Future<OrderOrganization> getPrintProfile() async {
    final dto = await _api.getPrintProfile();
    return _toOrganization(dto);
  }

  // ── Request building ───────────────────────────────────────────────────

  /// Builds the mobile create payload shared by orders + estimates.
  /// [deliveryDate] is sent only for orders (estimates carry none).
  Map<String, dynamic> _createBody(
    OrderDraftData draft, {
    DateTime? deliveryDate,
  }) {
    return <String, dynamic>{
      // Stable per-attempt key so a transparent retry is deduped server-side.
      'clientRequestId': generateUuidV4(),
      'customerId': draft.party!.id,
      'dateAD': DateTime.now().toIso8601String(),
      if (deliveryDate != null)
        'expectedDeliveryDate': deliveryDate.toIso8601String(),
      'overallDiscountPercent': draft.overallDiscountPercent,
      // Single document VAT rate (0 = No Tax). Server taxes the
      // post-discount base once, matching the builder's maths.
      'taxRate': draft.tax.rate,
      'items': <Map<String, dynamic>>[
        for (final line in draft.items)
          <String, dynamic>{
            'productId': line.productId,
            'quantity': line.quantity,
            // Net unit price; the server snapshots the name from the product.
            'unitPrice': line.basePrice,
            // Pre-markdown reference so the PDF can show the struck price.
            'listPrice': line.listedPrice,
          },
      ],
    };
  }

  // ── DTO → domain ───────────────────────────────────────────────────────

  Order _invoiceToOrder(InvoiceDto dto) => Order(
    id: dto.id,
    number: dto.invoiceNo,
    kind: OrderKind.order,
    status: _fulfillmentToStatus(dto.fulfillmentStatus),
    party: dto.customer == null ? null : _toParty(dto.customer!),
    deliveryDate: dto.expectedDeliveryDate,
    items: dto.items.map(_toLine).toList(growable: false),
    overallDiscountPercent: dto.overallDiscountPercent,
    tax: taxOptionForRate(dto.taxRate),
    createdAt: dto.createdAt,
  );

  Order _estimateToOrder(EstimateDto dto) => Order(
    id: dto.id,
    number: dto.estimateNo,
    kind: OrderKind.estimate,
    // Estimates don't surface a fulfilment status in the UI (the badge
    // reads "Estimate"); pending is an unused placeholder.
    status: OrderStatus.pending,
    party: dto.customer == null ? null : _toParty(dto.customer!),
    items: dto.items.map(_toLine).toList(growable: false),
    overallDiscountPercent: dto.overallDiscountPercent,
    tax: taxOptionForRate(dto.taxRate),
    createdAt: dto.createdAt,
  );

  OrderParty _toParty(OrderPartyDto dto) => OrderParty(
    id: dto.id,
    name: dto.name,
    ownerName: dto.ownerName ?? '',
    address: dto.address ?? '',
    panVat: dto.panVat ?? '',
    phone: dto.phone ?? '',
  );

  OrderLineItem _toLine(OrderLineItemDto dto) => OrderLineItem(
    // Free-text lines have no productId; fall back to the line id so the
    // card key stays stable.
    productId: dto.productId ?? dto.id,
    name: dto.description,
    imageUrl: dto.imageUrl,
    // No listPrice → the line carries no discount (list == net).
    listedPrice: dto.listPrice ?? dto.rate,
    quantity: dto.quantity.round(),
    basePrice: dto.rate,
    // Saved orders are read-only; availableStock isn't rendered, so the
    // ordered quantity is a safe self-consistent value.
    availableStock: dto.quantity.round(),
  );

  OrderOrganization _toOrganization(OrgPrintProfileDto dto) => OrderOrganization(
    name: dto.orgName,
    panVat: dto.orgPanVat ?? dto.branchPanVat ?? '',
    // Prefer the issuing branch's contact details on the document.
    phone: dto.branchPhone ?? dto.orgPhone ?? '',
    address: dto.branchAddress ?? dto.orgAddress ?? '',
  );

  OrderStatus _fulfillmentToStatus(String wire) => switch (wire) {
    'PENDING' => OrderStatus.pending,
    'IN_PROGRESS' => OrderStatus.inProgress,
    'IN_TRANSIT' => OrderStatus.inTransit,
    'COMPLETED' => OrderStatus.completed,
    'REJECTED' => OrderStatus.rejected,
    _ => OrderStatus.pending,
  };
}

/// Exposes the abstract type so consumers depend on the contract. Tests
/// override this with a fake `OrderRepository`.
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepositoryImpl(api: ref.watch(ordersApiProvider));
});
