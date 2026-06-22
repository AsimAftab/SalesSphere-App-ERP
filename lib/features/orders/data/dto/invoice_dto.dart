import 'package:sales_sphere_erp/features/orders/data/dto/order_line_item_dto.dart';
import 'package:sales_sphere_erp/features/orders/data/dto/order_party_dto.dart';

/// Wire DTO for an order, matching `GET /invoices` / `GET /invoices/{id}`.
/// On the mobile side an "order" is a backend invoice; the app reads the
/// field-ops fields (`fulfillmentStatus`, `expectedDeliveryDate`, the
/// order-level discount + tax) and ignores the accounting ones
/// (`status`, voucher ids).
///
/// Totals (`subtotal`/`vatAmount`/`totalAmount`) are intentionally not
/// decoded — the domain `Order` recomputes them from the line items via
/// `OrderTotals`, matching the builder's maths.
class InvoiceDto {
  const InvoiceDto({
    required this.id,
    required this.invoiceNo,
    required this.fulfillmentStatus,
    required this.overallDiscountPercent,
    required this.items,
    required this.createdAt,
    this.customer,
    this.expectedDeliveryDate,
    this.taxRate,
  });

  factory InvoiceDto.fromJson(Map<String, dynamic> json) => InvoiceDto(
    id: json['id'] as String,
    invoiceNo: json['invoiceNo'] as String,
    fulfillmentStatus: (json['fulfillmentStatus'] as String?) ?? 'PENDING',
    overallDiscountPercent: _toDouble(json['overallDiscountPercent']),
    taxRate: json['taxRate'] == null ? null : _toDouble(json['taxRate']),
    expectedDeliveryDate: json['expectedDeliveryDate'] == null
        ? null
        : DateTime.parse(json['expectedDeliveryDate'] as String),
    customer: json['customer'] == null
        ? null
        : OrderPartyDto.fromJson(json['customer'] as Map<String, dynamic>),
    items: ((json['items'] as List<dynamic>?) ?? const <dynamic>[])
        .map((j) => OrderLineItemDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  final String id;
  final String invoiceNo;
  final String fulfillmentStatus;
  final double overallDiscountPercent;
  final double? taxRate;
  final DateTime? expectedDeliveryDate;
  final OrderPartyDto? customer;
  final List<OrderLineItemDto> items;
  final DateTime createdAt;

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

/// One page of `GET /invoices`.
class InvoicesPageDto {
  const InvoicesPageDto({required this.items, this.nextCursor});

  final List<InvoiceDto> items;
  final String? nextCursor;
}
