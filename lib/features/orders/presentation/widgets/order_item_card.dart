import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/widgets/product_image.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_line_item.dart';
import 'package:sales_sphere_erp/features/orders/presentation/providers/order_providers.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';

final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

/// Editable order line: product thumbnail, name + listed price (struck
/// through when discounted), a delete button, a quantity stepper, the
/// linked base price / discount fields, and the live subtotal. Editing
/// base price updates the discount field and vice-versa (the discount is
/// the markdown off the listed price). Edits flow into the [OrderDraft]
/// notifier; the subtotal and the page summary rebuild off the draft.
class OrderItemCard extends ConsumerStatefulWidget {
  const OrderItemCard({required this.line, super.key});

  final OrderLineItem line;

  @override
  ConsumerState<OrderItemCard> createState() => _OrderItemCardState();
}

class _OrderItemCardState extends ConsumerState<OrderItemCard> {
  late final TextEditingController _quantityController;
  late final TextEditingController _basePriceController;
  late final TextEditingController _discountController;
  final FocusNode _quantityFocus = FocusNode();
  final FocusNode _basePriceFocus = FocusNode();
  final FocusNode _discountFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: '${widget.line.quantity}',
    );
    _basePriceController = TextEditingController(
      text: _num(widget.line.basePrice),
    );
    _discountController = TextEditingController(
      text: _num(widget.line.discountPercent, 1),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _basePriceController.dispose();
    _discountController.dispose();
    _quantityFocus.dispose();
    _basePriceFocus.dispose();
    _discountFocus.dispose();
    super.dispose();
  }

  /// Trims a double to a clean editable string (no trailing zeros).
  static String _num(double value, [int decimals = 2]) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    final s = value.toStringAsFixed(decimals);
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  /// Mirror a derived value into the field the user is *not* editing.
  /// Deferred + guarded so it never clobbers active typing or trips the
  /// build-phase `.text =` assertion.
  void _sync(TextEditingController controller, String next) {
    if (controller.text == next) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (controller.text == next) return;
      controller.text = next;
    });
  }

  OrderDraft get _draft => ref.read(orderDraftProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final discounted = line.savings > 0;

    if (!_quantityFocus.hasFocus) {
      _sync(_quantityController, '${line.quantity}');
    }
    if (!_basePriceFocus.hasFocus) {
      _sync(_basePriceController, _num(line.basePrice));
    }
    if (!_discountFocus.hasFocus) {
      _sync(_discountController, _num(line.discountPercent, 1));
    }

    return SectionCard(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 52.r,
              height: 52.r,
              child: ProductImage(
                name: line.name,
                imageUrl: line.imageUrl,
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    line.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Row(
                    children: <Widget>[
                      Text(
                        'List Price ${_currency.format(line.listedPrice)}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                          decoration: discounted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      if (discounted) ...<Widget>[
                        SizedBox(width: 8.w),
                        Text(
                          'Save ${_currency.format(line.savings)}',
                          style: TextStyle(
                            color: AppColors.green500,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: AppColors.error,
                size: 20.sp,
              ),
              tooltip: 'Remove item',
              visualDensity: VisualDensity.compact,
              onPressed: () => _draft.removeItem(line.productId),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Quantity',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${line.availableStock} in stock',
                  style: TextStyle(
                    color: line.quantity >= line.availableStock
                        ? AppColors.error
                        : AppColors.textHint,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _QuantityField(
              controller: _quantityController,
              focusNode: _quantityFocus,
              canDecrement: line.quantity > 1,
              canIncrement: line.quantity < line.availableStock,
              onDecrement: () =>
                  _draft.updateQuantity(line.productId, line.quantity - 1),
              onIncrement: () =>
                  _draft.updateQuantity(line.productId, line.quantity + 1),
              onTyped: (v) {
                final n = int.tryParse(v);
                if (n == null) return;
                if (n > line.availableStock) {
                  SnackbarUtils.showError(
                    context,
                    'Only ${line.availableStock} '
                    '${line.availableStock == 1 ? 'unit' : 'units'} in stock.',
                  );
                  // Snap the field back to the stock ceiling.
                  final capped = '${line.availableStock}';
                  _quantityController.value = TextEditingValue(
                    text: capped,
                    selection: TextSelection.collapsed(offset: capped.length),
                  );
                  _draft.updateQuantity(line.productId, line.availableStock);
                  return;
                }
                _draft.updateQuantity(line.productId, n);
              },
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: <Widget>[
            Expanded(
              child: _AdornedField(
                label: 'Unit Price',
                controller: _basePriceController,
                focusNode: _basePriceFocus,
                prefixText: 'Rs ',
                onChanged: (v) => _draft.updateBasePrice(
                  line.productId,
                  double.tryParse(v) ?? 0,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _AdornedField(
                label: 'Discount',
                controller: _discountController,
                focusNode: _discountFocus,
                suffixText: '%',
                onChanged: (v) => _draft.updateDiscountPercent(
                  line.productId,
                  double.tryParse(v) ?? 0,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        const Divider(height: 1, color: AppColors.border),
        SizedBox(height: 10.h),
        Row(
          children: <Widget>[
            Text(
              'Subtotal',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              _currency.format(line.subtotal),
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A minus / editable-field / plus control for the line quantity. The
/// middle field lets a large quantity be typed directly; the draft
/// notifier caps the value to the available stock.
class _QuantityField extends StatelessWidget {
  const _QuantityField({
    required this.controller,
    required this.focusNode,
    required this.canDecrement,
    required this.canIncrement,
    required this.onDecrement,
    required this.onIncrement,
    required this.onTyped,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canDecrement;
  final bool canIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final ValueChanged<String> onTyped;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepBtn(
            icon: Icons.remove,
            enabled: canDecrement,
            onTap: canDecrement ? onDecrement : null,
          ),
          SizedBox(
            width: 44.w,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: onTyped,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14.sp,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          _StepBtn(
            icon: Icons.add,
            enabled: canIncrement,
            onTap: canIncrement ? onIncrement : null,
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Icon(
          icon,
          size: 18.sp,
          color: enabled ? AppColors.secondary : AppColors.textHint,
        ),
      ),
    );
  }
}

/// Compact numeric field with a label and a Rs prefix or % suffix.
class _AdornedField extends StatelessWidget {
  const _AdornedField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.prefixText,
    this.suffixText,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String? prefixText;
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4.h),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
          ],
          onChanged: onChanged,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14.sp,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            prefixText: prefixText,
            suffixText: suffixText,
            prefixStyle: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
              fontFamily: 'Poppins',
            ),
            suffixStyle: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
              fontFamily: 'Poppins',
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 10.w,
              vertical: 10.h,
            ),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: const BorderSide(
                color: AppColors.secondary,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
