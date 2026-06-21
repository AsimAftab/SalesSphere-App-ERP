import 'package:flutter/foundation.dart';

import 'package:sales_sphere_erp/features/catalog/domain/product.dart';

/// A single product line on an order / estimate. Created from a catalog
/// [Product] when picked, then the quantity and base (selling) price are
/// edited on the order builder.
///
/// [basePrice] is the single source of truth for the unit price.
/// [discountPercent] is **derived** — the markdown of [basePrice] from
/// the catalog [listedPrice] — so editing the base price and editing the
/// discount are two views of the same value (see the draft notifier).
/// The line total therefore is simply `quantity * basePrice`.
@immutable
class OrderLineItem {
  const OrderLineItem({
    required this.productId,
    required this.name,
    required this.listedPrice,
    required this.quantity,
    required this.basePrice,
    required this.availableStock,
    this.imageUrl,
  });

  /// Builds a line from a catalog product, capturing its on-hand stock so
  /// the order can cap the quantity. Base price seeds from the listed
  /// price (i.e. no discount yet).
  factory OrderLineItem.fromProduct(Product product, {int quantity = 1}) {
    final stock = product.stock;
    final qty = quantity < 1 ? 1 : (stock > 0 && quantity > stock ? stock : quantity);
    return OrderLineItem(
      productId: product.id,
      name: product.name,
      imageUrl: product.imageUrl,
      listedPrice: product.price,
      quantity: qty,
      basePrice: product.price,
      availableStock: stock,
    );
  }

  /// Stable line id == the source product id.
  final String productId;
  final String name;
  final String? imageUrl;

  /// The product's catalog price at add-time — the reference the discount
  /// is measured against.
  final double listedPrice;

  /// Units ordered. Always >= 1 and capped to [availableStock].
  final int quantity;

  /// Units on hand for this product — the ceiling for [quantity].
  final int availableStock;

  /// Editable unit selling price.
  final double basePrice;

  /// Implied discount off the listed price, 0..100. Clamped to 0 when the
  /// base price is at or above listed (a markup shows no discount).
  double get discountPercent {
    if (listedPrice <= 0) return 0;
    final pct = (1 - basePrice / listedPrice) * 100;
    return pct < 0 ? 0 : pct;
  }

  /// Amount saved versus the listed price across the whole line.
  double get savings {
    final diff = (listedPrice - basePrice) * quantity;
    return diff < 0 ? 0 : diff;
  }

  /// Line total at the (discounted) base price.
  double get subtotal => quantity * basePrice;

  OrderLineItem copyWith({int? quantity, double? basePrice}) {
    return OrderLineItem(
      productId: productId,
      name: name,
      imageUrl: imageUrl,
      listedPrice: listedPrice,
      quantity: quantity ?? this.quantity,
      basePrice: basePrice ?? this.basePrice,
      availableStock: availableStock,
    );
  }
}
