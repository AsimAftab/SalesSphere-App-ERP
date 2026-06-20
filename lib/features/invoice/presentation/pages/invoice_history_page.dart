import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice.dart';
import 'package:sales_sphere_erp/features/invoice/presentation/controllers/invoice_controller.dart';
import 'package:sales_sphere_erp/features/invoice/presentation/providers/invoice_providers.dart';
import 'package:sales_sphere_erp/features/invoice/presentation/widgets/invoice_status_visuals.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/empty_state_view.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

/// History of saved invoices + estimates, split across two tabs. Each
/// card shows the document number, status, party, totals and dates, with
/// actions to download a PDF (stub) or open the detail page.
class InvoiceHistoryPage extends ConsumerStatefulWidget {
  const InvoiceHistoryPage({this.initialTab = 0, super.key});

  /// 0 = Invoices, 1 = Estimates. Set by the builder when it opens this
  /// page right after a create, so the matching tab is shown first.
  final int initialTab;

  @override
  ConsumerState<InvoiceHistoryPage> createState() => _InvoiceHistoryPageState();
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

  /// Tab label with a trailing count once data has loaded, e.g.
  /// "Invoices (5)". Hides the count while the list is empty/loading.
  String _tabLabel(String base, int count) =>
      count > 0 ? '$base ($count)' : base;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(invoiceHistoryProvider);
    final all = historyAsync.value ?? const <Invoice>[];
    final invoiceCount = all.where((i) => i.kind == InvoiceKind.invoice).length;
    final estimateCount = all
        .where((i) => i.kind == InvoiceKind.estimate)
        .length;

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
                      onPressed: () =>
                          ref.read(invoiceHistoryProvider.notifier).refresh(),
                      tooltip: 'Refresh',
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
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
                tabs: <Widget>[
                  Tab(text: _tabLabel('Invoices', invoiceCount)),
                  Tab(text: _tabLabel('Estimates', estimateCount)),
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
            itemBuilder: (_, __) => const _InvoiceCardSkeleton(),
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
          padding: EdgeInsets.fromLTRB(20.w, 72.h, 20.w, 28.h),
          children: <Widget>[
            _EmptyState(
              icon: kind == InvoiceKind.invoice
                  ? Icons.receipt_long_outlined
                  : Icons.description_outlined,
              title: kind == InvoiceKind.invoice
                  ? 'No invoices yet'
                  : 'No estimates yet',
              message: kind == InvoiceKind.invoice
                  ? 'Invoices you create will appear here.'
                  : 'Estimates you create will appear here.',
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
        itemBuilder: (context, index) => _InvoiceCard(invoice: items[index]),
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

/// Stub PDF export — the real generator lands with the backend. For now
/// it just acknowledges the action.
void _downloadPdf(BuildContext context, Invoice invoice) {
  SnackbarUtils.showSuccess(context, 'Preparing ${invoice.number}.pdf…');
}

final _dateFmt = DateFormat('dd MMM yyyy');

/// Rich history card: a leading document tile + number/status header, the
/// party, a totals/dates strip and Download PDF / View Detail actions.
/// Estimates additionally expose a delete affordance (they're disposable).
class _InvoiceCard extends ConsumerWidget {
  const _InvoiceCard({required this.invoice});

  final Invoice invoice;

  bool get _isEstimate => invoice.kind == InvoiceKind.estimate;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteEstimateDialog(number: invoice.number),
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(invoiceControllerProvider.notifier).deleteEstimate(invoice.id);
    SnackbarUtils.showSuccess(context, '${invoice.number} deleted.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeColor = invoiceBadgeColor(invoice);
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
            Routes.invoiceDetailPath(invoice.id),
            extra: invoice,
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
                      Text(
                        invoice.number,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        invoiceKindLabel(invoice.kind),
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
                StatusBadge(
                  label: invoiceBadgeLabel(invoice),
                  color: badgeColor,
                ),
                if (_isEstimate) ...<Widget>[
                  SizedBox(width: 2.w),
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
                    invoice.party?.name ?? 'No party',
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
                      value: _currency.format(invoice.grandTotal),
                      valueColor: AppColors.textPrimary,
                      valueWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: _Meta(
                      label: 'Created',
                      value: _dateFmt.format(invoice.createdAt),
                    ),
                  ),
                  Expanded(
                    child: _Meta(
                      label: 'Delivery',
                      value: invoice.deliveryDate == null
                          ? '—'
                          : _dateFmt.format(invoice.deliveryDate!),
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
                    onPressed: () => _downloadPdf(context, invoice),
                  ),
                ),
                SizedBox(width: 12.w),
                // Filled "View Details" — blue for invoices, teal for
                // estimates (matching the estimate badge).
                Expanded(
                  child: CustomButton(
                    label: 'View Details',
                    size: ButtonSize.small,
                    leadingIcon: Icons.visibility_outlined,
                    backgroundColor: invoiceKindColor(invoice.kind),
                    customIconSize: 16.sp,
                    customPadding: EdgeInsets.symmetric(horizontal: 8.w),
                    onPressed: () => context.push(
                      Routes.invoiceDetailPath(invoice.id),
                      extra: invoice,
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
/// [Bone] shapes rather than a real `_InvoiceCard`, because the card's
/// Material action buttons don't skeletonise cleanly (only the outlined
/// button's border shows). This mirrors the card's layout so the skeleton
/// reads as the same component.
class _InvoiceCardSkeleton extends StatelessWidget {
  const _InvoiceCardSkeleton();

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
