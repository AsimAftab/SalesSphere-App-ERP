import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/widgets/product_image.dart';

/// Catalog grid card: image, name, stock badge, price, and an
/// add-to-cart control. Ported from v1's `_ProductCard`, backed by the
/// in-memory [cartProvider]. `remaining = stock − quantity in cart`.
class CatalogProductCard extends ConsumerWidget {
  const CatalogProductCard({required this.product, super.key});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(cartProvider)[product.id] ?? 0;
    final remaining = product.stock - quantity;
    final canAdd = remaining > 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 5,
            child: SizedBox(
              width: double.infinity,
              child: ProductImage(
                name: product.name,
                imageUrl: product.imageUrl,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12.r),
                  topRight: Radius.circular(12.r),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: EdgeInsets.all(10.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      _StockBadge(remaining: remaining),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          'Rs ${product.price.toStringAsFixed(0)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: quantity > 0
                        ? _QuantityStepper(
                            quantity: quantity,
                            canAdd: canAdd,
                            onRemove: () => ref
                                .read(cartProvider.notifier)
                                .decrement(product.id),
                            onAdd: canAdd
                                ? () => ref
                                      .read(cartProvider.notifier)
                                      .add(product.id)
                                : null,
                          )
                        : _AddButton(
                            enabled: canAdd,
                            onTap: canAdd
                                ? () => ref
                                      .read(cartProvider.notifier)
                                      .add(product.id)
                                : null,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final inStock = remaining > 0;
    final color = inStock ? AppColors.green500 : AppColors.red500;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        inStock ? 'Qty: $remaining' : 'Out of Stock',
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30.h,
        decoration: BoxDecoration(
          color: enabled ? AppColors.secondary : AppColors.greyMedium,
          borderRadius: BorderRadius.circular(15.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              enabled ? Icons.add : Icons.block,
              size: 14.sp,
              color: Colors.white,
            ),
            SizedBox(width: 4.w),
            Text(
              enabled ? 'Add' : 'Out of Stock',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.canAdd,
    required this.onRemove,
    required this.onAdd,
  });

  final int quantity;
  final bool canAdd;
  final VoidCallback onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30.h,
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _StepperButton(
            icon: quantity == 1 ? Icons.delete_outline : Icons.remove,
            enabled: true,
            onTap: onRemove,
          ),
          Text(
            '$quantity',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          _StepperButton(icon: Icons.add, enabled: canAdd, onTap: onAdd),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26.w,
        height: 26.h,
        margin: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.2 : 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 14.sp,
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
