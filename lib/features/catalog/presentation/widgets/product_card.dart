import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/widgets/product_image.dart';

/// At or below this remaining count the card surfaces a low-stock warning
/// ("Only N left") instead of the calm in-stock line.
const _lowStockThreshold = 5;

/// Catalog grid card. Premium stacked layout — hero image, name, hero
/// price, a colour-coded stock line, then the add-to-cart control. Backed
/// by the in-memory [cartProvider]; `remaining = stock − quantity in cart`.
class CatalogProductCard extends ConsumerWidget {
  const CatalogProductCard({required this.product, super.key});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(cartProvider)[product.id] ?? 0;
    final remaining = product.stock - quantity;
    final canAdd = remaining > 0;
    final soldOut = product.stock <= 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        // Refined hero-card shadow: a soft branded primary glow plus a
        // tight ambient shadow to seat the card on the page.
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Hero image fills the space the stacked content below doesn't
          // need, so a one-line name simply gives the image more room.
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ProductImage(
                    name: product.name,
                    imageUrl: product.imageUrl,
                    borderRadius: BorderRadius.zero,
                  ),
                  if (soldOut) ...<Widget>[
                    // Dim the image + a small ribbon so unavailability reads
                    // at a glance without hunting for the stock line.
                    Positioned.fill(
                      child: ColoredBox(
                        color: AppColors.surface.withValues(alpha: 0.55),
                      ),
                    ),
                    Positioned(
                      top: 8.h,
                      left: 8.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.red500,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'Out of stock',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 6.h),
                // Hero price — the figure that should anchor the card.
                Text(
                  'Rs ${product.price.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 6.h),
                _StockLine(remaining: remaining),
                SizedBox(height: 10.h),
                if (quantity > 0)
                  _QuantityStepper(
                    quantity: quantity,
                    canAdd: canAdd,
                    onRemove: () =>
                        ref.read(cartProvider.notifier).decrement(product.id),
                    onAdd: canAdd
                        ? () => ref.read(cartProvider.notifier).add(product.id)
                        : null,
                  )
                else
                  _AddButton(
                    enabled: canAdd,
                    onTap: canAdd
                        ? () => ref.read(cartProvider.notifier).add(product.id)
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small colour-coded dot + label conveying availability: calm green
/// when comfortably stocked, amber when running low, red when out.
class _StockLine extends StatelessWidget {
  const _StockLine({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final (Color dot, Color text, String label) = switch (remaining) {
      <= 0 => (AppColors.red500, AppColors.red500, 'Out of stock'),
      <= _lowStockThreshold => (
        AppColors.warning,
        AppColors.warning,
        'Only $remaining left',
      ),
      _ => (
        AppColors.green500,
        AppColors.textSecondary,
        'In stock · $remaining',
      ),
    };

    return Row(
      children: <Widget>[
        Container(
          width: 7.r,
          height: 7.r,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        SizedBox(width: 6.w),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: text,
            ),
          ),
        ),
      ],
    );
  }
}

/// Add-to-cart pill. Same height + radius as [_QuantityStepper] so the
/// control area doesn't shift when the first unit is added.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? Colors.white : AppColors.textHint;
    return Material(
      color: enabled ? AppColors.secondary : AppColors.greyLight,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: SizedBox(
          height: 34.h,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.add_rounded, size: 16.sp, color: fg),
              SizedBox(width: 5.w),
              Text(
                'Add',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
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
      height: 34.h,
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(12.r),
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
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
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
        width: 28.w,
        height: 28.w,
        margin: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.22 : 0.08),
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
