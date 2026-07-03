import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/widgets/product_image.dart';
import 'package:sales_sphere_erp/features/orders/domain/order.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_line_item.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_organization.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_party.dart';
import 'package:sales_sphere_erp/features/orders/presentation/controllers/order_controller.dart';
import 'package:sales_sphere_erp/features/orders/presentation/pdf_export.dart';
import 'package:sales_sphere_erp/features/orders/presentation/providers/order_providers.dart';
import 'package:sales_sphere_erp/features/orders/presentation/widgets/convert_to_order_dialog.dart';
import 'package:sales_sphere_erp/features/orders/presentation/widgets/order_status_visuals.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);
final _dateFmt = DateFormat('dd MMM yyyy');

/// Read-only detail view of a saved order / estimate. Receives the
/// record via `extra` ([initial]) to render instantly; falls back to
/// [orderByIdProvider] when opened cold (e.g. a deep link).
class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({required this.id, this.initial, super.key});

  final String id;
  final Order? initial;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.orderHistory);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prefer the live record from the store so a pull-to-refresh / header
    // refresh reflects updates; [initial] (passed via `extra`) is the
    // instant-paint fallback for cold opens / deep links.
    final order = ref.watch(orderByIdProvider(id)) ?? initial;

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: order == null
              ? _NotFound(onBack: () => _back(context))
              : _Body(order: order, onBack: () => _back(context)),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.order, required this.onBack});

  final Order order;
  final VoidCallback onBack;

  bool get _isEstimate => order.kind == OrderKind.estimate;

  Future<void> _convertToOrder(BuildContext context, WidgetRef ref) async {
    final deliveryDate = await ConvertToOrderDialog.show(context);
    if (deliveryDate == null || !context.mounted) return;

    final Order created;
    try {
      created = await ref
          .read(orderControllerProvider.notifier)
          .convertToOrder(order, deliveryDate);
    } on Object {
      if (!context.mounted) return;
      SnackbarUtils.showError(
        context,
        "Couldn't convert ${order.number}. Please try again.",
      );
      return;
    }
    if (!context.mounted) return;

    SnackbarUtils.showSuccess(
      context,
      '${order.number} converted to ${created.number}.',
    );
    context.pushReplacement(
      Routes.orderDetailPath(created.id),
      extra: created,
    );
  }

  Future<void> _refresh(WidgetRef ref) =>
      ref.read(orderHistoryProvider.notifier).refresh();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The "From" profile loads async; show em-dash placeholders until it
    // resolves (the rest of the page renders from the passed-in order).
    final organization =
        ref.watch(orderOrganizationProvider).value ??
        const OrderOrganization(name: '—', panVat: '', phone: '', address: '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(4.w, 4.h, 8.w, 0),
          child: Row(
            children: <Widget>[
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: AppColors.textdark,
                  size: 20.sp,
                ),
                onPressed: onBack,
                tooltip: 'Back',
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '${orderKindLabel(order.kind)} Details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: AppColors.primary,
                  size: 22.sp,
                ),
                onPressed: () => _refresh(ref),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        SizedBox(height: 4.h),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _refresh(ref),
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // ── Summary header (number + status + dates) ────────────
                  _SummaryHeaderCard(order: order),
                  SizedBox(height: 20.h),
                  // ── From (selling organisation) ──────────────────────────
                  const _SectionHeader(
                    icon: Icons.business_outlined,
                    title: 'From',
                  ),
                  SizedBox(height: 10.h),
                  _PartyInfoCard(
                    accent: AppColors.primary,
                    icon: Icons.apartment_rounded,
                    heading: organization.name,
                    rows: <_Field>[
                      _Field('PAN / VAT', organization.panVat),
                      _Field('Phone', organization.phone),
                      _Field('Address', organization.address),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  // ── Bill To (party) ──────────────────────────────────────
                  const _SectionHeader(
                    icon: Icons.account_circle_outlined,
                    title: 'Bill To',
                  ),
                  SizedBox(height: 10.h),
                  _PartyInfoCard(
                    accent: AppColors.secondary,
                    icon: Icons.storefront_rounded,
                    heading: order.party?.name ?? '—',
                    rows: _billToRows(order.party),
                  ),
                  SizedBox(height: 20.h),
                  // ── Items ────────────────────────────────────────────────
                  _SectionHeader(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Items',
                    trailing: '${order.items.length}',
                  ),
                  SizedBox(height: 10.h),
                  SectionCard(
                    children: <Widget>[
                      for (
                        var i = 0;
                        i < order.items.length;
                        i++
                      ) ...<Widget>[
                        if (i > 0) _divider(),
                        _LineRow(line: order.items[i]),
                      ],
                    ],
                  ),
                  SizedBox(height: 20.h),
                  // ── Summary ──────────────────────────────────────────────
                  const _SectionHeader(
                    icon: Icons.receipt_outlined,
                    title: 'Summary',
                  ),
                  SizedBox(height: 10.h),
                  SectionCard(
                    children: <Widget>[
                      _SummaryRow(
                        label: 'Subtotal',
                        value: order.itemsSubtotal,
                      ),
                      if (order.overallDiscountPercent > 0)
                        _SummaryRow(
                          label:
                              'Overall discount '
                              '(${_pct(order.overallDiscountPercent)}%)',
                          value: -order.overallDiscountAmount,
                        ),
                      if (order.tax.rate > 0) ...<Widget>[
                        _SummaryRow(
                          label: 'Taxable amount',
                          value: order.taxableBase,
                        ),
                        _SummaryRow(
                          label: order.tax.label,
                          value: order.taxAmount,
                        ),
                      ],
                      SizedBox(height: 8.h),
                      const Divider(height: 1, color: AppColors.border),
                      SizedBox(height: 10.h),
                      Row(
                        children: <Widget>[
                          Text(
                            'Total',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _currency.format(order.grandTotal),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      _TotalCaption(order: order),
                    ],
                  ),
                  SizedBox(height: 22.h),
                  // ── Actions ──────────────────────────────────────────────
                  if (_isEstimate) ...<Widget>[
                    PrimaryButton(
                      label: 'Convert to Order',
                      leadingIcon: Icons.swap_horiz_rounded,
                      onPressed: () => _convertToOrder(context, ref),
                    ),
                    SizedBox(height: 12.h),
                    OutlinedCustomButton(
                      label: 'Download PDF',
                      leadingIcon: Icons.download_rounded,
                      onPressed: () => downloadOrderPdf(context, ref, order),
                    ),
                  ] else
                    PrimaryButton(
                      label: 'Download PDF',
                      leadingIcon: Icons.download_rounded,
                      onPressed: () => downloadOrderPdf(context, ref, order),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static List<_Field> _billToRows(OrderParty? party) {
    if (party == null) return const <_Field>[];
    return <_Field>[
      _Field('Owner', party.ownerName),
      _Field('PAN / VAT', party.panVat),
      _Field('Phone', party.phone),
      _Field('Address', party.address),
    ];
  }

  static Widget _divider() =>
      const Divider(height: 18, color: AppColors.border);

  static String _pct(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

/// Light summary header: a tinted document tile + number/kind and the
/// status badge, over a two-column Created / Expected-delivery strip.
/// Replaces the old standalone dates card and gives the page a premium,
/// at-a-glance top section without a heavy dark hero.
class _SummaryHeaderCard extends StatelessWidget {
  const _SummaryHeaderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final badgeColor = orderBadgeColor(order);
    final isEstimate = order.kind == OrderKind.estimate;
    return SectionCard(
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 44.r,
              height: 44.r,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              alignment: Alignment.center,
              child: Icon(
                isEstimate
                    ? Icons.description_outlined
                    : Icons.receipt_long_outlined,
                size: 23.sp,
                color: badgeColor,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    order.number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    orderKindLabel(order.kind),
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // Estimates are self-evident from the kind label above, so the
            // "Estimate" badge is redundant; orders keep their status badge.
            if (!isEstimate) ...<Widget>[
              SizedBox(width: 8.w),
              StatusBadge(label: orderBadgeLabel(order), color: badgeColor),
            ],
          ],
        ),
        const Divider(height: 24, color: AppColors.border),
        Row(
          children: <Widget>[
            Expanded(
              child: _HeaderMeta(
                icon: Icons.event_outlined,
                label: 'Created',
                value: _dateFmt.format(order.createdAt),
              ),
            ),
            // Estimates have no delivery date — only orders carry one.
            if (!isEstimate)
              Expanded(
                child: _HeaderMeta(
                  icon: Icons.local_shipping_outlined,
                  label: 'Expected delivery',
                  value: order.deliveryDate == null
                      ? '—'
                      : _dateFmt.format(order.deliveryDate!),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Icon + stacked label/value used in the summary header's date strip.
class _HeaderMeta extends StatelessWidget {
  const _HeaderMeta({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16.sp, color: AppColors.textSecondary),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(color: AppColors.textHint, fontSize: 12.sp),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A labelled field for the From / Bill To cards. Empty values render as
/// an em-dash so the card stays aligned.
class _Field {
  const _Field(this.label, this.value);

  final String label;
  final String value;
}

/// "From" / "Bill To" card: an accent-tinted icon tile + heading (the
/// organisation / party name) over a stack of labelled detail rows.
class _PartyInfoCard extends StatelessWidget {
  const _PartyInfoCard({
    required this.accent,
    required this.icon,
    required this.heading,
    required this.rows,
  });

  final Color accent;
  final IconData icon;
  final String heading;
  final List<_Field> rows;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11.r),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 21.sp, color: accent),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                heading,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (rows.isNotEmpty) ...<Widget>[
          const Divider(height: 22, color: AppColors.border),
          for (var i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: 12.h),
            _DetailRow(
              label: rows[i].label,
              value: rows[i].value.trim().isEmpty ? '—' : rows[i].value,
            ),
          ],
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: AppColors.primary, size: 18.sp),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (trailing != null) ...<Widget>[
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              trailing!,
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 110.w,
          child: Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final OrderLineItem line;

  @override
  Widget build(BuildContext context) {
    final discounted = line.discountPercent > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Title row: thumbnail + name (+ struck listed price when
        // discounted) and the line amount on the right.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 48.r,
              height: 48.r,
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
                      color: AppColors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (discounted) ...<Widget>[
                    SizedBox(height: 3.h),
                    Text(
                      'List Price ${_currency.format(line.listedPrice)}',
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12.sp,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Amount',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12.sp),
                ),
                SizedBox(height: 2.h),
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
        ),
        SizedBox(height: 10.h),
        // Labelled breakdown so quantity, unit price and discount can't be
        // misread against each other.
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _LineMetric(
                  label: 'Quantity',
                  value: '${line.quantity}',
                ),
              ),
              _metricDivider(),
              Expanded(
                child: _LineMetric(
                  label: 'Unit Price',
                  value: _currency.format(line.basePrice),
                ),
              ),
              _metricDivider(),
              Expanded(
                child: _LineMetric(
                  label: 'Discount',
                  value: discounted
                      ? '${_pctText(line.discountPercent)}%'
                      : '—',
                  valueColor: discounted ? AppColors.negative : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _metricDivider() => Container(
    width: 1,
    height: 26.h,
    margin: EdgeInsets.symmetric(horizontal: 10.w),
    color: AppColors.border,
  );

  static String _pctText(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

/// One labelled metric (label over bold value) in the detail item card's
/// quantity / unit-price / discount strip.
class _LineMetric extends StatelessWidget {
  const _LineMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(color: AppColors.textHint, fontSize: 12.sp),
        ),
        SizedBox(height: 3.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    // Deductions (negative values — e.g. the overall discount) read in red
    // so it's clear the amount is subtracted from the total.
    final isDeduction = value < 0;
    final formatted = isDeduction
        ? '- ${_currency.format(value.abs())}'
        : _currency.format(value);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            formatted,
            style: TextStyle(
              color: isDeduction ? AppColors.negative : AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: isDeduction ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Caption under the grand total: item / unit count on the left and the
/// total savings (line discounts + overall discount) on the right —
/// parity with the builder's total chip, so the figures the user tuned
/// while building carry through to the saved record.
class _TotalCaption extends StatelessWidget {
  const _TotalCaption({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final itemCount = order.items.length;
    final unitCount = order.items.fold<int>(0, (sum, i) => sum + i.quantity);
    final savings =
        order.items.fold<double>(0, (sum, i) => sum + i.savings) +
        order.overallDiscountAmount;

    return Row(
      children: <Widget>[
        Text(
          '$itemCount ${itemCount == 1 ? 'item' : 'items'} · '
          '$unitCount ${unitCount == 1 ? 'unit' : 'units'}',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
        ),
        const Spacer(),
        if (savings > 0)
          Text(
            'You save ${_currency.format(savings)}',
            style: TextStyle(
              color: AppColors.green500,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 0),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: AppColors.textdark,
                size: 20.sp,
              ),
              onPressed: onBack,
              tooltip: 'Back',
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Text(
                "This record isn't available.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
