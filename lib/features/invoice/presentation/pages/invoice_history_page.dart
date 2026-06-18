import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice.dart';
import 'package:sales_sphere_erp/features/invoice/domain/tax_option.dart';
import 'package:sales_sphere_erp/features/invoice/presentation/providers/invoice_providers.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

/// History of saved invoices + estimates, split across two tabs. The
/// per-record detail view is out of scope for now, so rows are not
/// tappable.
class InvoiceHistoryPage extends ConsumerStatefulWidget {
  const InvoiceHistoryPage({this.initialTab = 0, super.key});

  /// 0 = Invoices, 1 = Estimates. Set by the builder when it opens this
  /// page right after a create, so the matching tab is shown first.
  final int initialTab;

  @override
  ConsumerState<InvoiceHistoryPage> createState() =>
      _InvoiceHistoryPageState();
}

class _InvoiceHistoryPageState extends ConsumerState<InvoiceHistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.invoice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(invoiceHistoryProvider);

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 0),
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
                    SizedBox(width: 12.w),
                    Text(
                      'Invoice History',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.secondary,
                indicatorWeight: 3,
                labelStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const <Widget>[
                  Tab(text: 'Invoices'),
                  Tab(text: 'Estimates'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    _HistoryList(
                      async: historyAsync,
                      kind: InvoiceKind.invoice,
                      onRefresh: () =>
                          ref.read(invoiceHistoryProvider.notifier).refresh(),
                    ),
                    _HistoryList(
                      async: historyAsync,
                      kind: InvoiceKind.estimate,
                      onRefresh: () =>
                          ref.read(invoiceHistoryProvider.notifier).refresh(),
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

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.async,
    required this.kind,
    required this.onRefresh,
  });

  final AsyncValue<List<Invoice>> async;
  final InvoiceKind kind;
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
            itemBuilder: (_, __) => _InvoiceRow(invoice: _placeholderInvoice),
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

    final items = async.requireValue
        .where((i) => i.kind == kind)
        .toList(growable: false);

    if (items.isEmpty) {
      return wrapRefresh(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 80.h, 20.w, 28.h),
          children: <Widget>[
            _message(
              kind == InvoiceKind.invoice
                  ? 'No invoices yet.'
                  : 'No estimates yet.',
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
        itemBuilder: (context, index) => _InvoiceRow(invoice: items[index]),
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

/// Minimal history row — number, party, date and grand total.
class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final party = invoice.party?.name ?? 'No party';
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
        padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    invoice.number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  _currency.format(invoice.grandTotal),
                  style: TextStyle(
                    color: AppColors.green500,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: <Widget>[
                Icon(
                  Icons.storefront_outlined,
                  size: 14.sp,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    party,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.event_outlined,
                  size: 14.sp,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 6.w),
                Text(
                  DateFormat('dd MMM yyyy').format(invoice.createdAt),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
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

/// Sample row painted under Skeletonizer while the list loads.
final _placeholderInvoice = Invoice(
  id: '',
  number: 'INV-0000',
  kind: InvoiceKind.invoice,
  items: const [],
  overallDiscountPercent: 0,
  tax: const TaxOption(id: 'none', label: 'No Tax', rate: 0),
  createdAt: DateTime(2026),
);
