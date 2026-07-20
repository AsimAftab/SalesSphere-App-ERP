import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:sales_sphere_erp/features/orders/domain/order.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_draft_data.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_party.dart';
import 'package:sales_sphere_erp/features/orders/presentation/controllers/order_controller.dart';
import 'package:sales_sphere_erp/features/orders/presentation/providers/order_providers.dart';
import 'package:sales_sphere_erp/features/orders/presentation/widgets/order_item_card.dart';
import 'package:sales_sphere_erp/features/parties/presentation/providers/parties_providers.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_option_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/empty_state_view.dart';
import 'package:sales_sphere_erp/shared/widgets/party_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);

/// Order builder — the Order tab's landing page. Pick a party (its
/// owner auto-fills), set a delivery date, add catalog items, tune the
/// base price / discount + tax, then create an order or estimate.
/// Watches [orderDraftProvider]; all maths is derived from the draft.
class OrderPage extends ConsumerStatefulWidget {
  const OrderPage({super.key});

  @override
  ConsumerState<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends ConsumerState<OrderPage> {
  final _ownerController = TextEditingController();
  final _deliveryDateController = TextEditingController();
  final _overallDiscountController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(orderDraftProvider);
    _ownerController.text = draft.party?.ownerName ?? '';
    if (draft.deliveryDate != null) {
      _deliveryDateController.text = DateFormat(
        'dd MMM yyyy',
      ).format(draft.deliveryDate!);
    }
    if (draft.overallDiscountPercent != 0) {
      _overallDiscountController.text = _num(draft.overallDiscountPercent);
    }
    // Pull anything staged in the catalog cart into the draft. Covers the
    // "browse the catalog tab, then open the order" flow (this page is
    // recreated whenever the tab is shown). Deferred so we don't mutate a
    // provider during init.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mergeCartIntoDraft();
    });
  }

  /// Moves any catalog-cart products into the order draft, then empties
  /// the cart. Safe to call repeatedly — already-added products are kept.
  void _mergeCartIntoDraft() {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    // The catalogue is async now — only merge against what's already loaded
    // (the user reached the cart by browsing it, so it is). If absent, the
    // cart is preserved and merged on the next entry.
    final products =
        ref.read(catalogProductsProvider).value ?? const <Product>[];
    if (products.isEmpty) return;
    ref.read(orderDraftProvider.notifier).addFromCart(cart, products);
    ref.read(cartProvider.notifier).clear();
  }

  /// Switches to the Catalog tab to add items. Products added to the cart
  /// there are merged into the draft when the user returns to this tab —
  /// handled by [initState]'s [_mergeCartIntoDraft].
  void _addItems() => context.go(Routes.catalog);

  @override
  void dispose() {
    _ownerController.dispose();
    _deliveryDateController.dispose();
    _overallDiscountController.dispose();
    super.dispose();
  }

  static String _num(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  /// Keep the read-only owner field mirrored to the selected party.
  /// Deferred + guarded to avoid the build-phase `.text =` assertion.
  void _syncOwner(String next) {
    if (_ownerController.text == next) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_ownerController.text == next) return;
      _ownerController.text = next;
    });
  }

  Future<void> _create(OrderKind kind) async {
    final draft = ref.read(orderDraftProvider);
    if (draft.isEmpty) {
      SnackbarUtils.showError(context, 'Add at least one item first.');
      return;
    }
    // A party is required for both orders and estimates. The expected
    // delivery date is required only for orders.
    if (draft.party == null) {
      SnackbarUtils.showError(context, 'Select a party first.');
      return;
    }
    if (kind == OrderKind.order && draft.deliveryDate == null) {
      SnackbarUtils.showError(
        context,
        'Set an expected delivery date to create an order.',
      );
      return;
    }

    setState(() => _submitting = true);
    final controller = ref.read(orderControllerProvider.notifier);
    final Order created;
    try {
      created = kind == OrderKind.order
          ? await controller.createOrder()
          : await controller.createEstimate();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final isCreditError =
          extractBackendErrorCode(e) == 'CREDIT_LIMIT_EXCEEDED';
      SnackbarUtils.showError(
        context,
        isCreditError
            ? 'Order blocked: Credit limit exceeded. Check status card above or save as Estimate.'
            : (extractBackendErrorMessage(e) ??
                "Couldn't create the ${orderKindLabel(kind).toLowerCase()}. "
                    'Please try again.'),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);

    // Draft was reset by the controller — clear the local field text too.
    _deliveryDateController.clear();
    _overallDiscountController.clear();

    SnackbarUtils.showSuccess(
      context,
      '${orderKindLabel(kind)} ${created.number} created.',
    );
    unawaited(context.push(Routes.orderHistory, extra: kind.index));
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(orderDraftProvider);
    _syncOwner(draft.party?.ownerName ?? '');

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        // Lifted above the shell's floating glass bottom nav so it stays
        // visible (the shell uses `extendBody`, so the nav overlays the
        // page).
        floatingActionButton: Padding(
          padding: EdgeInsets.only(bottom: 84.h),
          child: PrimaryFabButton(label: 'Add Item', onPressed: _addItems),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Header(onHistory: () => context.push(Routes.orderHistory)),
              SizedBox(height: 4.h),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 160.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _SectionHeader(
                        icon: Icons.storefront_outlined,
                        title: 'Party Details',
                      ),
                      SizedBox(height: 10.h),
                      _PartyDetailCard(
                        draft: draft,
                        ownerController: _ownerController,
                        deliveryDateController: _deliveryDateController,
                      ),
                      SizedBox(height: 20.h),
                      _SectionHeader(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Items',
                        trailing: draft.items.isEmpty
                            ? null
                            : '${draft.items.length}',
                      ),
                      SizedBox(height: 10.h),
                      _ItemsSection(draft: draft),
                      // Summary is meaningless without items — keep it hidden
                      // until the first product is added.
                      if (!draft.isEmpty) ...<Widget>[
                        SizedBox(height: 20.h),
                        const _SectionHeader(
                          icon: Icons.receipt_outlined,
                          title: 'Summary',
                        ),
                        SizedBox(height: 10.h),
                        _SummaryCard(
                          draft: draft,
                          overallDiscountController: _overallDiscountController,
                        ),
                      ],
                      SizedBox(height: 20.h),
                      _OrderCreditWarningCard(draft: draft),
                      PrimaryButton(
                        label: 'Create Order',
                        leadingIcon: Icons.check_circle_outline,
                        height: 50.h,
                        width: double.infinity,
                        isLoading: _submitting,
                        // Nothing to create without items — keep both actions
                        // disabled until the first product is added.
                        isDisabled: draft.isEmpty,
                        onPressed: _submitting
                            ? null
                            : () => _create(OrderKind.order),
                      ),
                      SizedBox(height: 12.h),
                      // While empty, render the estimate action as a disabled
                      // filled button so its disabled state matches the Create
                      // Order button exactly. Once items exist it returns to
                      // its normal outlined style.
                      if (draft.isEmpty)
                        PrimaryButton(
                          label: 'Create Estimate',
                          leadingIcon: Icons.description_outlined,
                          height: 50.h,
                          width: double.infinity,
                          isDisabled: true,
                        )
                      else
                        OutlinedCustomButton(
                          label: 'Create Estimate',
                          leadingIcon: Icons.description_outlined,
                          height: 50.h,
                          width: double.infinity,
                          isLoading: _submitting,
                          onPressed: _submitting
                              ? null
                              : () => _create(OrderKind.estimate),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onHistory});

  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 12.w, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'New Order',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Build an order or estimate',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.history, color: AppColors.primary, size: 24.sp),
            tooltip: 'Order history',
            onPressed: onHistory,
          ),
        ],
      ),
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

class _PartyDetailCard extends ConsumerWidget {
  const _PartyDetailCard({
    required this.draft,
    required this.ownerController,
    required this.deliveryDateController,
  });

  final OrderDraftData draft;
  final TextEditingController ownerController;
  final TextEditingController deliveryDateController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(orderDraftProvider.notifier);
    final now = DateTime.now();
    return SectionCard(
      children: <Widget>[
        PartyPickerField<OrderParty>(
          value: draft.party,
          onChanged: (party) {
            if (party == null) {
              notifier.clearParty();
            } else {
              notifier.selectParty(party);
            }
          },
          items:
              ref.watch(orderPartiesProvider).value ?? const <OrderParty>[],
          titleOf: (p) => p.name,
          subtitleOf: (p) => '${p.ownerName} · ${p.address}',
          searchTextOf: (p) => '${p.name} ${p.ownerName} ${p.address}',
          label: 'Party',
          hintText: 'Select or search a party',
          sheetTitle: 'Select party',
          searchHint: 'Search parties',
          emptyText: 'No parties yet.',
          noMatchText: 'No parties match your search.',
        ),
        if (draft.party != null) _PartyCreditBanner(partyId: draft.party!.id),
        SizedBox(height: 14.h),
        PrimaryTextField(
          controller: ownerController,
          label: 'Owner name',
          hintText: 'Auto-filled from party',
          prefixIcon: Icons.person_outline,
          enabled: false,
          readOnly: true,
        ),
        SizedBox(height: 14.h),
        CustomDatePicker(
          controller: deliveryDateController,
          label: 'Expected delivery date',
          hintText: 'Select a date',
          prefixIcon: Icons.local_shipping_outlined,
          initialDate: draft.deliveryDate,
          // Delivery can't be in the past — today is the earliest day.
          firstDate: DateTime(now.year, now.month, now.day),
          onDateSelected: notifier.setDeliveryDate,
        ),
      ],
    );
  }
}

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({required this.draft});

  final OrderDraftData draft;

  @override
  Widget build(BuildContext context) {
    if (draft.isEmpty) return const _EmptyItems();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final line in draft.items) ...<Widget>[
          OrderItemCard(key: ValueKey<String>(line.productId), line: line),
          SizedBox(height: 12.h),
        ],
      ],
    );
  }
}

class _EmptyItems extends StatelessWidget {
  const _EmptyItems();

  @override
  Widget build(BuildContext context) {
    // Shared empty-state treatment (muted icon + title + message in a white
    // card), matching the unplanned-visits and odometer home pages.
    return SectionCard(
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 24.w),
      children: const <Widget>[
        EmptyStateView(
          icon: Icons.add_shopping_cart_outlined,
          title: 'No items added yet',
          message: 'Tap the "Add Item" button to pick products '
              'from the catalog.',
        ),
      ],
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({
    required this.draft,
    required this.overallDiscountController,
  });

  final OrderDraftData draft;
  final TextEditingController overallDiscountController;

  double get _totalSavings {
    final lineSavings = draft.items.fold<double>(
      0,
      (sum, i) => sum + i.savings,
    );
    return lineSavings + draft.overallDiscountAmount;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(orderDraftProvider.notifier);
    final taxes = ref.watch(taxOptionsProvider);
    final totalUnits = draft.items.fold<int>(0, (sum, i) => sum + i.quantity);

    return SectionCard(
      children: <Widget>[
        PrimaryTextField(
          controller: overallDiscountController,
          label: 'Overall discount (%)',
          hintText: 'e.g. 5',
          prefixIcon: Icons.percent_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
          ],
          onChanged: (v) =>
              notifier.setOverallDiscountPercent(double.tryParse(v) ?? 0),
        ),
        SizedBox(height: 14.h),
        CustomOptionPicker(
          // Show the placeholder (not a preselected "No Tax") until the
          // user picks a tax — mirrors the empty discount field. The draft
          // still defaults to No Tax internally so the maths is correct;
          // here `none` simply renders as "unselected".
          value: draft.tax.id == 'none' ? null : draft.tax.label,
          options: taxes.map((t) => t.label).toList(growable: false),
          label: 'Tax',
          hintText: 'Select tax',
          prefixIcon: Icons.account_balance_outlined,
          sheetTitle: 'Select tax',
          sheetIcon: Icons.account_balance_outlined,
          onChanged: (label) {
            // Clearing the selection falls back to No Tax.
            notifier.setTax(
              label == null
                  ? taxes.firstWhere((t) => t.id == 'none')
                  : taxes.firstWhere((t) => t.label == label),
            );
          },
        ),
        SizedBox(height: 16.h),
        const Divider(height: 1, color: AppColors.border),
        SizedBox(height: 12.h),
        _BreakdownRow(label: 'Subtotal', value: draft.itemsSubtotal),
        if (draft.overallDiscountPercent > 0)
          _BreakdownRow(
            label: 'Overall discount (${_pct(draft.overallDiscountPercent)}%)',
            value: -draft.overallDiscountAmount,
          ),
        if (draft.tax.rate > 0) ...<Widget>[
          _BreakdownRow(label: 'Taxable amount', value: draft.taxableBase),
          _BreakdownRow(label: draft.tax.label, value: draft.taxAmount),
        ],
        SizedBox(height: 12.h),
        _TotalChip(
          total: draft.grandTotal,
          itemCount: draft.items.length,
          unitCount: totalUnits,
          savings: _totalSavings,
        ),
      ],
    );
  }

  static String _pct(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.value});

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

class _TotalChip extends StatelessWidget {
  const _TotalChip({
    required this.total,
    required this.itemCount,
    required this.unitCount,
    required this.savings,
  });

  final double total;
  final int itemCount;
  final int unitCount;
  final double savings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
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
              _currency.format(total),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Row(
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
        ),
      ],
    );
  }
}

class _PartyCreditBanner extends ConsumerWidget {
  const _PartyCreditBanner({required this.partyId});

  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditAsync = ref.watch(partyCreditProvider(partyId));
    final partyAsync = ref.watch(partyByIdProvider(partyId));

    if (creditAsync.isLoading && !creditAsync.hasValue) {
      return Padding(
        padding: EdgeInsets.only(top: 14.h),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: AppColors.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 16.w,
                height: 16.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                'Checking credit limit and exposure...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final credit = creditAsync.value;
    if (credit != null) {
      if (credit.isUnlimited) {
        return const SizedBox.shrink();
      }

      final exposure = double.tryParse(credit.totalExposure) ?? 0;
      final outstanding = double.tryParse(credit.postedOutstanding) ?? 0;
      final pendingOrders = double.tryParse(credit.draftOrdersTotal) ?? 0;
      final limit = double.tryParse(credit.creditLimitAmount ?? '') ?? 0;
      final available =
          double.tryParse(credit.availableCredit ?? '') ?? (limit - exposure);
      final isOverLimit = available <= 0 || credit.isOverLimit;

      return Padding(
        padding: EdgeInsets.only(top: 14.h),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isOverLimit
                  ? AppColors.error.withValues(alpha: 0.6)
                  : AppColors.border,
              width: isOverLimit ? 1.5 : 1.0,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: isOverLimit ? AppColors.error : AppColors.textSecondary,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Credit Status',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              _ComparisonRow(
                label: 'Credit Limit',
                value: _currency.format(limit),
              ),
              _ComparisonRow(
                label: 'Outstanding',
                value: _currency.format(outstanding),
              ),
              _ComparisonRow(
                label: 'Pending Orders',
                value: _currency.format(pendingOrders),
              ),
              _ComparisonRow(
                label: 'Total Exposure',
                value: _currency.format(exposure),
              ),
              _ComparisonRow(
                label: 'Available Credit',
                value: _currency.format(available),
                valueColor: isOverLimit ? AppColors.error : AppColors.success,
              ),
              if (isOverLimit) ...<Widget>[
                SizedBox(height: 6.h),
                Text(
                  'Over limit — new orders will be blocked until payments '
                  'are collected.',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final party = partyAsync.value;
    if (party != null && party.creditLimitAmount != null) {
      final limit = double.tryParse(party.creditLimitAmount!) ?? 0;
      if (limit > 0) {
        return Padding(
          padding: EdgeInsets.only(top: 14.h),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.border),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.cloud_off_outlined,
                  color: AppColors.textSecondary,
                  size: 18.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Credit Limit: ${_currency.format(limit)} (Live exposure offline)',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }
}


class _OrderCreditWarningCard extends ConsumerWidget {
  const _OrderCreditWarningCard({required this.draft});

  final OrderDraftData draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (draft.party == null || draft.isEmpty) return const SizedBox.shrink();

    final credit = ref.watch(partyCreditProvider(draft.party!.id)).value;
    if (credit == null || credit.isUnlimited) return const SizedBox.shrink();

    final limit = double.tryParse(credit.creditLimitAmount ?? '') ?? 0;
    final exposure = double.tryParse(credit.totalExposure) ?? 0;
    final available =
        double.tryParse(credit.availableCredit ?? '') ?? (limit - exposure);

    if (draft.grandTotal > available || available <= 0 || credit.isOverLimit) {
      final deficit = draft.grandTotal - available;
      return Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.6)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.gpp_bad_outlined,
                color: AppColors.error,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    available <= 0
                        ? 'Customer Over Credit Limit'
                        : 'Order Exceeds Available Credit',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    available <= 0
                        ? 'Current balance: ${_currency.format(available)}. Confirmed orders may be blocked until dues are cleared.'
                        : 'Exceeds balance by ${_currency.format(deficit > 0 ? deficit : draft.grandTotal)} (Available: ${_currency.format(available)}).',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.sp,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if ((available - draft.grandTotal) < (limit * 0.15)) {
      return Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.orange500.withValues(alpha: 0.5)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.orange500.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: AppColors.orange500,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Low Credit After Order',
                    style: TextStyle(
                      color: AppColors.orange500,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Confirming this order (${_currency.format(draft.grandTotal)}) will leave only ${_currency.format(available - draft.grandTotal)} in available credit.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11.5.sp,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 13.sp,
              fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
