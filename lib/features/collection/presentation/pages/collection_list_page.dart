import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';
import 'package:sales_sphere_erp/features/collection/presentation/providers/collection_providers.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/empty_state_view.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_search_filter.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// `Rs 12,500` style formatter for collected amounts.
final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

class CollectionListPage extends ConsumerStatefulWidget {
  const CollectionListPage({super.key});

  @override
  ConsumerState<CollectionListPage> createState() => _CollectionListPageState();
}

class _CollectionListPageState extends ConsumerState<CollectionListPage> {
  final _searchController = TextEditingController();
  String _query = '';

  /// `null` means "All" — no payment-mode filter applied. Otherwise the
  /// list narrows to collections whose [Collection.paymentMode] matches.
  PaymentMode? _modeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.fieldOps);
    }
  }

  /// Apply the in-page search query + payment-mode filter against the
  /// loaded collections.
  List<Collection> _applyFilters(List<Collection> source) {
    final q = _query.trim().toLowerCase();
    return source.where((c) {
      if (_modeFilter != null && c.paymentMode != _modeFilter) return false;
      if (q.isEmpty) return true;
      return c.party.name.toLowerCase().contains(q) ||
          c.paymentMode.label.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  bool get _hasActiveFilter =>
      _query.trim().isNotEmpty || _modeFilter != null;

  @override
  Widget build(BuildContext context) {
    final collectionsAsync = ref.watch(collectionListProvider);

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: PrimaryFabButton(
          label: 'Add Collection',
          onPressed: () => context.push(Routes.addCollection),
        ),
        body: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SvgPicture.asset(
                'assets/images/corner_bubble.svg',
                fit: BoxFit.cover,
                height: 180.h,
              ),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  _AppBar(onBack: _back),
                  SizedBox(height: 46.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: PrimaryTextField(
                      controller: _searchController,
                      hintText: 'Search',
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
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                                FocusManager.instance.primaryFocus?.unfocus();
                              },
                              tooltip: 'Clear search',
                            ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: PrimarySearchFilter<PaymentMode?>(
                      selected: _modeFilter,
                      onChanged: (next) => setState(() => _modeFilter = next),
                      options: <SearchFilterOption<PaymentMode?>>[
                        const SearchFilterOption<PaymentMode?>(
                          value: null,
                          label: 'All',
                          icon: Icons.list_alt_rounded,
                        ),
                        for (final m in PaymentMode.values)
                          SearchFilterOption<PaymentMode?>(
                            value: m,
                            label: m.label,
                            icon: m.icon,
                            iconColor: m.accent,
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'My Collections',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Expanded(child: _buildBody(collectionsAsync)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<Collection>> collectionsAsync) {
    final padding = EdgeInsets.fromLTRB(20.w, 0, 20.w, 140.h);

    Widget wrapRefresh(Widget child) => RefreshIndicator(
          onRefresh: () =>
              ref.read(collectionListProvider.notifier).refresh(),
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: child,
        );

    // First load — paint a skeleton list. Pull-to-refresh is still
    // available so a stuck initial fetch can be retried.
    if (collectionsAsync.isLoading && !collectionsAsync.hasValue) {
      return wrapRefresh(
        Skeletonizer(
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: padding,
            itemCount: 5,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (_, __) =>
                _CollectionCard(collection: _placeholder, onTap: () {}),
          ),
        ),
      );
    }

    if (collectionsAsync.hasError && !collectionsAsync.hasValue) {
      return wrapRefresh(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 80.h, 20.w, 140.h),
          children: const <Widget>[_ErrorState()],
        ),
      );
    }

    final items = _applyFilters(collectionsAsync.requireValue);
    if (items.isEmpty) {
      return wrapRefresh(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 80.h, 20.w, 140.h),
          children: <Widget>[
            _EmptyState(hasActiveFilter: _hasActiveFilter),
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
        itemBuilder: (context, index) {
          final collection = items[index];
          return _CollectionCard(
            collection: collection,
            onTap: () => context.push(
              Routes.collectionDetailPath(collection.id),
              extra: collection,
            ),
          );
        },
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 0),
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
          SizedBox(width: 12.w),
          Text(
            'Collection',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal collection row — who the money came from (party), how it was
/// paid (payment-mode chip), how much (amount) and when (date).
class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection, required this.onTap});

  final Collection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mode = collection.paymentMode;
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
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
                        collection.party.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    StatusBadge(label: mode.label, color: mode.accent),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: <Widget>[
                    Text(
                      _currency.format(collection.amount),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.event_outlined,
                      size: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      DateFormat('dd MMM yyyy').format(collection.receivedDate),
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
        ),
      ),
    );
  }
}

/// Sample collection fed to [_CollectionCard] while the list is loading.
/// Skeletonizer paints bones over the rendered party / amount / date.
final _placeholder = Collection(
  id: '',
  party: const CollectionParty(
    id: '',
    name: 'Loading party name',
    address: '',
  ),
  amount: 10000,
  receivedDate: DateTime(2026),
  paymentMode: PaymentMode.cash,
  createdAt: DateTime(2026),
);

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasActiveFilter});

  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.account_balance_wallet_outlined,
      title: hasActiveFilter ? 'No matches' : 'No collections yet',
      message: hasActiveFilter
          ? 'No collections match the current filters.'
          : 'Tap "Add Collection" to record your first one.',
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          "Couldn't load collections. Pull to retry.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}
