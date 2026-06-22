/// One line of an invoice / estimate response. Shared shape across both
/// (the backend `InvoiceItemDto` / `EstimateItemDto` are identical).
///
/// Money + quantity arrive as decimal strings ("5.000", "1250.00"); the
/// domain works in `double` / `int`, so they're parsed here. `rate` is the
/// net unit price; `listPrice` is the optional pre-markdown reference.
class OrderLineItemDto {
  const OrderLineItemDto({
    required this.id,
    required this.description,
    required this.quantity,
    required this.rate,
    this.productId,
    this.listPrice,
    this.imageUrl,
  });

  factory OrderLineItemDto.fromJson(Map<String, dynamic> json) =>
      OrderLineItemDto(
        id: json['id'] as String,
        productId: json['productId'] as String?,
        description: (json['description'] as String?) ?? '',
        quantity: _toDouble(json['quantity']),
        rate: _toDouble(json['rate']),
        listPrice: json['listPrice'] == null
            ? null
            : _toDouble(json['listPrice']),
        imageUrl: json['imageUrl'] as String?,
      );

  final String id;
  final String? productId;
  final String description;
  final double quantity;
  final double rate;
  final double? listPrice;
  final String? imageUrl;

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
