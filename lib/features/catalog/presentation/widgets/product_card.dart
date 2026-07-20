import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/widgets/product_image.dart';
import 'package:skeletonizer/skeletonizer.dart';

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
    final soldOut = product.stock <= 0;    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.6),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
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
          // Hero image area with subtle background for transparent logos
          // Compact, professionally sized image container (105.h)
          SizedBox(
            height: 105.h,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ProductImage(
                      name: product.name,
                      imageUrl: product.imageUrl,
                      borderRadius: BorderRadius.zero,
                    ),
                    if (soldOut) ...<Widget>[
                      Positioned.fill(
                        child: ColoredBox(
                          color: AppColors.surface.withValues(alpha: 0.65),
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
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.red500.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
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
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      SizedBox(height: 5.h),
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
                      SizedBox(height: 4.h),
                      _StockBadge(remaining: remaining),
                    ],
                  ),
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
          ),
        ],
      ),
    );
  }
}

/// A clean indicator conveying availability: emerald dot when comfortably
/// stocked, amber when running low, red when out.
class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final (Color dot, String status, Color statusColor, String? qtyText) =
        switch (remaining) {
      <= 0 => (
        AppColors.red500,
        'Sold out',
        AppColors.red500,
        null,
      ),
      <= _lowStockThreshold => (
        AppColors.orange500,
        'Low stock',
        AppColors.orange500,
        '• Only $remaining left',
      ),
      _ => (
        const Color(0xFF10B981),
        'In stock',
        const Color(0xFF0F766E),
        '• $remaining units',
      ),
    };

    return Skeleton.replace(
      replacement: Bone(
        width: 90.w,
        height: 16.h,
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 6.r,
            height: 6.r,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(fontSize: 11.sp),
                children: <TextSpan>[
                  TextSpan(
                    text: status,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                  if (qtyText != null)
                    TextSpan(
                      text: '  $qtyText',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
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

/// Add-to-cart pill. Same height + radius as [_QuantityStepper] so the
/// control area doesn't shift when the first unit is added.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? Colors.white : AppColors.textHint;
    return Skeleton.replace(
      replacement: Bone(
        width: double.infinity,
        height: 34.h,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Container(
        height: 34.h,
        decoration: BoxDecoration(
          color: enabled ? AppColors.secondary : AppColors.greyLight,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10.r),
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
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
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
