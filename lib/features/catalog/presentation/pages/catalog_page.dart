import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product_category.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/widgets/category_chip.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/widgets/category_visuals.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/widgets/product_card.dart';
import 'package:sales_sphere_erp/shared/widgets/empty_state_view.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// Catalog tab: searchable, category-filterable 2-column product grid
/// backed by mock data. Ported from v1's `CatalogScreen`. Search is
/// client-side (local `_query`); the category filter is the shared
/// [selectedCategoryProvider]; cards drive the in-memory cart.
///
/// The order builder's "Add Item" button switches to this tab; products
/// added to the cart here are merged into the order draft when the user
/// returns to the Order tab (see `OrderPage` initState).
class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filter(List<Product> products, String? categoryId) {
    final q = _query.trim().toLowerCase();
    return products
        .where((p) {
          if (categoryId != null && p.categoryId != categoryId) return false;
          if (q.isEmpty) return true;
          return p.name.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q);
        })
        .toList(growable: false);
  }

  /// Pull-to-refresh. Invalidates the catalogue providers so the repository
  /// refetches `/products` + `/product-categories`.
  Future<void> _refresh() async {
    ref
      ..invalidate(catalogProductsProvider)
      ..invalidate(catalogCategoriesProvider);
    // Let the refetch settle so the indicator has a visible beat.
    await ref.read(catalogProductsProvider.future);
  }

  /// Empty-or-grid for the loaded product list. The empty branch stays
  /// scrollable so the pull-to-refresh gesture works with no products.
  Widget _grid(List<Product> items) {
    if (items.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: _EmptyProducts(hasQuery: _query.trim().isNotEmpty),
          ),
        ),
      );
    }
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 140.h),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.60,
        crossAxisSpacing: 14.w,
        mainAxisSpacing: 14.h,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          CatalogProductCard(product: items[index]),
    );
  }

  /// Centred loader on first load, kept scrollable so the refresh gesture
  /// stays available.
  Widget _loading() => _centeredScrollable(
    const Center(child: CircularProgressIndicator(color: AppColors.primary)),
  );

  Widget _error() => _centeredScrollable(
    const EmptyStateView(
      icon: Icons.cloud_off_rounded,
      title: "Couldn't load products",
      message: 'Pull down to retry.',
    ),
  );

  Widget _centeredScrollable(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: SizedBox(height: constraints.maxHeight, child: child),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(catalogProductsProvider);
    final categories =
        ref.watch(catalogCategoriesProvider).value ??
        const <ProductCategory>[];
    final selectedCategoryId = ref.watch(selectedCategoryProvider);

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
                child: Text(
                  'Product Catalog',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: PrimaryTextField(
                  controller: _searchController,
                  hintText: 'Search products or SKU',
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
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                            FocusManager.instance.primaryFocus?.unfocus();
                          },
                        ),
                ),
              ),
              SizedBox(height: 12.h),
              _CategoryChips(
                categories: categories,
                selectedId: selectedCategoryId,
              ),
              SizedBox(height: 12.h),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  child: productsAsync.when(
                    data: (products) =>
                        _grid(_filter(products, selectedCategoryId)),
                    loading: _loading,
                    error: (_, __) => _error(),
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

/// Horizontal category filter row. The leading "All" chip opens the
/// category-selection grid (matching v1); the rest toggle the shared
/// category filter. The selected chip is scrolled into view so the active
/// category stays visible as confirmation — important after picking a
/// category from the All-categories grid, which may otherwise leave the
/// highlighted pill off-screen.
class _CategoryChips extends ConsumerStatefulWidget {
  const _CategoryChips({required this.categories, required this.selectedId});

  final List<ProductCategory> categories;
  final String? selectedId;

  @override
  ConsumerState<_CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends ConsumerState<_CategoryChips> {
  // Tags the currently-selected chip so we can scroll it into view.
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ensureSelectedVisible();
  }

  @override
  void didUpdateWidget(_CategoryChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) _ensureSelectedVisible();
  }

  void _ensureSelectedVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _selectedKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = widget.selectedId == null;
    final chips = <Widget>[
      CategoryChip(
        key: allSelected ? _selectedKey : null,
        label: 'All',
        icon: Icons.grid_view_rounded,
        selected: allSelected,
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          context.push(Routes.catalogCategories);
        },
      ),
      for (final cat in widget.categories) ...<Widget>[
        SizedBox(width: 8.w),
        Builder(
          builder: (context) {
            final selected = widget.selectedId == cat.id;
            return CategoryChip(
              key: selected ? _selectedKey : null,
              label: cat.name,
              icon: categoryVisuals(cat.name).icon,
              selected: selected,
              onTap: () =>
                  ref.read(selectedCategoryProvider.notifier).select(cat.id),
            );
          },
        ),
      ],
    ];

    // A non-lazy scroll view (vs. ListView.builder) keeps every chip built
    // so an off-screen selected chip can still be scrolled into view.
    return SizedBox(
      height: 48.h,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Row(children: chips),
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.inventory_2_outlined,
      title: 'No products found',
      message: hasQuery
          ? 'Try a different search or category.'
          : 'Products will appear here.',
    );
  }
}
