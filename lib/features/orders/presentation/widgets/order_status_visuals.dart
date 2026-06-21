import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/orders/domain/order.dart';

/// Accent colour per order status — shared by the history badge and the
/// detail page so they read as the same component family.
Color orderStatusColor(OrderStatus status) => switch (status) {
  OrderStatus.pending => AppColors.warning,
  OrderStatus.inProgress => AppColors.secondary,
  OrderStatus.inTransit => AppColors.purple500,
  OrderStatus.completed => AppColors.green500,
  OrderStatus.rejected => AppColors.error,
};

IconData orderStatusIcon(OrderStatus status) => switch (status) {
  OrderStatus.pending => Icons.hourglass_empty_rounded,
  OrderStatus.inProgress => Icons.autorenew_rounded,
  OrderStatus.inTransit => Icons.local_shipping_outlined,
  OrderStatus.completed => Icons.check_circle_outline_rounded,
  OrderStatus.rejected => Icons.cancel_outlined,
};

/// Badge label for a saved record. Estimates always read "Estimate"
/// (their non-binding nature is what matters, not a fulfilment status);
/// orders show their fulfilment status.
String orderBadgeLabel(Order order) =>
    order.kind == OrderKind.estimate
    ? 'Estimate'
    : orderStatusLabel(order.status);

/// Accent colour for [orderBadgeLabel]. Estimates use the orange
/// [AppColors.textOrange] — a warm accent that clearly sets quotations
/// apart from the blue orders. It is also the estimate's "View Details"
/// button colour, so the badge matches its button. Orders keep their
/// per-status colour.
Color orderBadgeColor(Order order) => order.kind == OrderKind.estimate
    ? AppColors.textOrange
    : orderStatusColor(order.status);

/// Filled-button accent per document kind: orders use the brand blue
/// [AppColors.secondary], estimates the orange [AppColors.textOrange].
/// Drives the "View Details" button so the two kinds are tellable apart at
/// a glance. Both take white foreground text.
Color orderKindColor(OrderKind kind) => kind == OrderKind.estimate
    ? AppColors.textOrange
    : AppColors.secondary;
