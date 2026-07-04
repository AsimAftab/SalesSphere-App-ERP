import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/orders/domain/order.dart';
import 'package:sales_sphere_erp/features/orders/presentation/controllers/order_controller.dart';
import 'package:sales_sphere_erp/features/orders/presentation/pdf_export.dart';
import 'package:sales_sphere_erp/features/orders/presentation/providers/order_providers.dart';
import 'package:sales_sphere_erp/features/orders/presentation/widgets/order_status_visuals.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/empty_state_view.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_search_filter.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

/// History of saved orders + estimates, split across two tabs. Each
/// card shows the document number, status, party, totals and dates, with
/// actions to download a PDF (stub) or open the detail page.
class OrderHistoryPage extends ConsumerStatefulWidget {
  const OrderHistoryPage({this.initialTab = 0, super.key});

  /// 0 = Orders, 1 = Estimates. Set by the builder when it opens this
  /// page right after a create, so the matching tab is shown first.
  final int initialTab;

  @override
  ConsumerState<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends ConsumerState<OrderHistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  /// Search query applied to both tabs — matches the document number
  /// (order / estimate number) and the party name.
  String _query = '';

  /// Status filter for the Orders tab. `null` means "all statuses".
  /// Estimates ignore it — they carry no fulfilment status worth filtering.
  OrderStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.order);
    }
  }

  /// Tab label with a trailing count once data has loaded, e.g.
  /// "Orders (5)". Hides the count while the list is empty/loading.
  String _tabLabel(String base, int count) =>
      count > 0 ? '$base ($count)' : base;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(orderHistoryProvider);
    final all = historyAsync.value ?? const <Order>[];
    final query = _query.trim().toLowerCase();

    bool matchesQuery(Order o) {
      if (query.isEmpty) return true;
      return o.number.toLowerCase().contains(query) ||
          (o.party?.name.toLowerCase().contains(query) ?? false);
    }

    // Search applies to both tabs; the status filter only narrows orders.
    final orders = <Order>[
      for (final o in all)
        if (o.kind == OrderKind.order &&
            matchesQuery(o) &&
            (_statusFilter == null || o.status == _statusFilter))
          o,
    ];
    final estimates = <Order>[
      for (final o in all)
        if (o.kind == OrderKind.estimate && matchesQuery(o)) o,
    ];

    final hasQuery = query.isNotEmpty;
    Future<void> refresh() =>
        ref.read(orderHistoryProvider.notifier).refresh();

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
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
                      onPressed: _back,
                      tooltip: 'Back',
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'History',
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
                      onPressed: refresh,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              // Search bar — applies to both tabs (number + party name).
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: PrimaryTextField(
                  controller: _searchController,
                  hintText: 'Search by number or party',
                  prefixIcon: Icons.search,
                  onChanged: (v) => setState(() => _query = v),
                  suffixWidget: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 20.sp,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: _clearSearch,
                          tooltip: 'Clear search',
                        ),
                ),
              ),
              SizedBox(height: 12.h),
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.secondary,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
                tabs: <Widget>[
                  Tab(text: _tabLabel('Orders', orders.length)),
                  Tab(text: _tabLabel('Estimates', estimates.length)),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    // Orders tab — the status filter is pinned above the list
                    // and lives INSIDE the tab, so switching tabs slides it
                    // away horizontally instead of popping the page layout.
                    Column(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
                          child: _StatusFilterBar(
                            selected: _statusFilter,
                            onChanged: (next) =>
                                setState(() => _statusFilter = next),
                          ),
                        ),
                        Expanded(
                          child: _HistoryList(
                            async: historyAsync,
                            items: orders,
                            kind: OrderKind.order,
                            isFiltered: hasQuery || _statusFilter != null,
                            onRefresh: refresh,
                          ),
                        ),
                      ],
                    ),
                    _HistoryList(
                      async: historyAsync,
                      items: estimates,
                      kind: OrderKind.estimate,
                      isFiltered: hasQuery,
                      onRefresh: refresh,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status filter for the Orders tab — "All Statuses" plus one option per
/// [OrderStatus], each carrying the same icon + colour as its status badge.
class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onChanged});

  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PrimarySearchFilter<OrderStatus?>(
      selected: selected,
      onChanged: onChanged,
      options: <SearchFilterOption<OrderStatus?>>[
        const SearchFilterOption<OrderStatus?>(
          value: null,
          label: 'All Statuses',
          icon: Icons.list_alt_rounded,
        ),
        for (final s in OrderStatus.values)
          SearchFilterOption<OrderStatus?>(
            value: s,
            label: orderStatusLabel(s),
            icon: orderStatusIcon(s),
            iconColor: orderStatusColor(s),
          ),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.async,
    required this.items,
    required this.kind,
    required this.isFiltered,
    required this.onRefresh,
  });

  final AsyncValue<List<Order>> async;

  /// Already filtered by [kind] + search + (for orders) status. The list
  /// renders these as-is; the source [async] is kept only to distinguish
  /// loading / error from a genuinely empty result.
  final List<Order> items;
  final OrderKind kind;

  /// True when a search query or status filter is narrowing the list, so an
  /// empty result reads as "no matches" rather than "nothing created yet".
  final bool isFiltered;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h);

    Widget wrapRefresh(Widget child) => RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: child,
    );

    if (async.isLoading && !async.hasValue) {
      return wrapRefresh(
        Skeletonizer(
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: padding,
            itemCount: 4,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (_, __) => const _OrderCardSkeleton(),
          ),
        ),
      );
    }

    if (async.hasError && !async.hasValue) {
      return wrapRefresh(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 80.h, 20.w, 28.h),
          children: <Widget>[_message("Couldn't load history. Pull to retry.")],
        ),
      );
    }

    if (items.isEmpty) {
      final isOrder = kind == OrderKind.order;
      final noun = isOrder ? 'orders' : 'estimates';
      return wrapRefresh(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 72.h, 20.w, 28.h),
          children: <Widget>[
            _EmptyState(
              icon: isOrder
                  ? Icons.receipt_long_outlined
                  : Icons.description_outlined,
              title: isFiltered
                  ? 'No matches'
                  : (isOrder ? 'No orders yet' : 'No estimates yet'),
              message: isFiltered
                  ? 'No $noun match your search${isOrder ? ' or filter' : ''}.'
                  : '${isOrder ? 'Orders' : 'Estimates'} you create will '
                        'appear here.',
            ),
          ],
        ),
      );
    }

    return wrapRefresh(
      ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) => _OrderCard(order: items[index]),
      ),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
      ),
    ),
  );
}

/// Friendly empty-tab placeholder: a muted icon over a title and a one-line
/// hint. Delegates to the shared [EmptyStateView] so the feature's empty
/// states read as one family with the rest of the app.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(icon: icon, title: title, message: message);
  }
}

final _dateFmt = DateFormat('dd MMM yyyy');

/// Rich history card: a leading document tile + number/status header, the
/// party, a totals/dates strip and Download PDF / View Detail actions.
/// Estimates additionally expose a delete affordance (they're disposable).
class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final Order order;

  bool get _isEstimate => order.kind == OrderKind.estimate;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteEstimateDialog(number: order.number),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(orderControllerProvider.notifier).deleteEstimate(order.id);
      if (!context.mounted) return;
      SnackbarUtils.showSuccess(context, '${order.number} deleted.');
    } on Object {
      if (!context.mounted) return;
      SnackbarUtils.showError(context, "Couldn't delete ${order.number}.");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeColor = orderBadgeColor(order);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: () => context.push(
            Routes.orderDetailPath(order.id),
            extra: order,
          ),
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
        padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 38.r,
                  height: 38.r,
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11.r),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _isEstimate
                        ? Icons.description_outlined
                        : Icons.receipt_long_outlined,
                    size: 20.sp,
                    color: badgeColor,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Order numbers (e.g. ORD-ACMETR-HO-82-0004) can be
                      // long; scale the text down to fit the card width
                      // instead of truncating it with an ellipsis.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          order.number,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
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
                SizedBox(width: 8.w),
                // Estimates are self-evident from the kind label, so they skip
                // the redundant "Estimate" badge — the delete action takes its
                // place. Orders show their fulfilment-status badge.
                if (!_isEstimate)
                  StatusBadge(
                    label: orderBadgeLabel(order),
                    color: badgeColor,
                  )
                else
                  SizedBox(
                    width: 34.w,
                    height: 34.w,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 19.sp,
                        color: AppColors.error,
                      ),
                      tooltip: 'Delete estimate',
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 10.h),
            Row(
              children: <Widget>[
                Icon(
                  Icons.storefront_outlined,
                  size: 15.sp,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    order.party?.name ?? 'No party',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _Meta(
                      label: 'Amount',
                      value: _currency.format(order.grandTotal),
                      valueColor: AppColors.textPrimary,
                      valueWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: _Meta(
                      label: 'Created',
                      value: _dateFmt.format(order.createdAt),
                    ),
                  ),
                  // Estimates have no delivery date — only orders carry one.
                  if (!_isEstimate)
                    Expanded(
                      child: _Meta(
                        label: 'Delivery',
                        value: order.deliveryDate == null
                            ? '—'
                            : _dateFmt.format(order.deliveryDate!),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              children: <Widget>[
                // Outlined navy "Download PDF" — the shared CustomButton with
                // a tightened horizontal padding so the label + icon stay on
                // one line in the narrow half-card width.
                Expanded(
                  child: CustomButton(
                    label: 'Download PDF',
                    type: ButtonType.outlined,
                    size: ButtonSize.small,
                    leadingIcon: Icons.download_rounded,
                    textColor: AppColors.primary,
                    borderColor: AppColors.primary,
                    customIconSize: 16.sp,
                    customPadding: EdgeInsets.symmetric(horizontal: 8.w),
                    onPressed: () => downloadOrderPdf(context, ref, order),
                  ),
                ),
                SizedBox(width: 12.w),
                // Filled "View Details" — blue for orders, teal for
                // estimates (matching the estimate badge).
                Expanded(
                  child: CustomButton(
                    label: 'View Details',
                    size: ButtonSize.small,
                    leadingIcon: Icons.visibility_outlined,
                    backgroundColor: orderKindColor(order.kind),
                    customIconSize: 16.sp,
                    customPadding: EdgeInsets.symmetric(horizontal: 8.w),
                    onPressed: () => context.push(
                      Routes.orderDetailPath(order.id),
                      extra: order,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

/// Destructive-confirmation card for deleting an estimate. Mirrors the
/// settings "Sign out?" dialog so destructive confirmations read the same
/// across the app: a centred card with a red icon disc, a title + message,
/// and Cancel / Delete actions side by side. Resolves to `true` on Delete.
class _DeleteEstimateDialog extends StatelessWidget {
  const _DeleteEstimateDialog({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 56.r,
                height: 56.r,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 28.sp,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Delete estimate?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Are you sure you want to delete $number? '
              'This action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
                height: 1.4,
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedCustomButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: CustomButton(
                    label: 'Delete',
                    backgroundColor: AppColors.error,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small stacked label + value used in the card's meta row.
class _Meta extends StatelessWidget {
  const _Meta({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWeight = FontWeight.w500,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// Defaults to a regular w500 so dates read calmly; the amount tile
  /// passes a heavier weight to stand out as the key figure.
  final FontWeight valueWeight;

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
        SizedBox(height: 2.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 14.sp,
            fontWeight: valueWeight,
          ),
        ),
      ],
    );
  }
}

/// Loading placeholder painted under [Skeletonizer]. Built from explicit
/// [Bone] shapes rather than a real `_OrderCard`, because the card's
/// Material action buttons don't skeletonise cleanly (only the outlined
/// button's border shows). This mirrors the card's layout so the skeleton
/// reads as the same component.
class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Bone(
                  width: 38.r,
                  height: 38.r,
                  borderRadius: BorderRadius.circular(11.r),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Bone(
                        width: 120.w,
                        height: 14.h,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      SizedBox(height: 6.h),
                      Bone(
                        width: 60.w,
                        height: 10.h,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Bone(
                  width: 72.w,
                  height: 24.h,
                  borderRadius: BorderRadius.circular(40.r),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Bone(
              width: 150.w,
              height: 14.h,
              borderRadius: BorderRadius.circular(4.r),
            ),
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: <Widget>[
                  for (var i = 0; i < 3; i++) ...<Widget>[
                    if (i > 0) SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Bone(
                            width: 44.w,
                            height: 9.h,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          SizedBox(height: 8.h),
                          Bone(
                            width: 56.w,
                            height: 12.h,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: Bone(
                    height: 40.h,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Bone(
                    height: 40.h,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
