import 'package:sales_sphere_erp/features/orders/data/dto/order_line_item_dto.dart';
import 'package:sales_sphere_erp/features/orders/data/dto/order_party_dto.dart';

/// Wire DTO for an estimate (quotation), matching `GET /estimates` /
/// `GET /estimates/{id}`. Mirrors the invoice DTO minus the order-only
/// fields (fulfilment status, delivery date) and plus `convertedInvoiceId`,
/// set once the estimate has been converted into an order.
class EstimateDto {
  const EstimateDto({
    required this.id,
    required this.estimateNo,
    required this.overallDiscountPercent,
    required this.items,
    required this.createdAt,
    this.customer,
    this.taxRate,
    this.convertedInvoiceId,
  });

  factory EstimateDto.fromJson(Map<String, dynamic> json) => EstimateDto(
    id: json['id'] as String,
    estimateNo: json['estimateNo'] as String,
    overallDiscountPercent: _toDouble(json['overallDiscountPercent']),
    taxRate: json['taxRate'] == null ? null : _toDouble(json['taxRate']),
    convertedInvoiceId: json['convertedInvoiceId'] as String?,
    customer: json['customer'] == null
        ? null
        : OrderPartyDto.fromJson(json['customer'] as Map<String, dynamic>),
    items: ((json['items'] as List<dynamic>?) ?? const <dynamic>[])
        .map((j) => OrderLineItemDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  final String id;
  final String estimateNo;
  final double overallDiscountPercent;
  final double? taxRate;
  final String? convertedInvoiceId;
  final OrderPartyDto? customer;
  final List<OrderLineItemDto> items;
  final DateTime createdAt;

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

/// One page of `GET /estimates`.
class EstimatesPageDto {
  const EstimatesPageDto({required this.items, this.nextCursor});

  final List<EstimateDto> items;
  final String? nextCursor;
}
