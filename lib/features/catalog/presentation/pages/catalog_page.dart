import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product_category.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/widgets/category_chip.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/widgets/category_visuals.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/widgets/product_card.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// Catalog tab: searchable, category-filterable 2-column product grid
/// backed by mock data. Ported from v1's `CatalogScreen`. Search is
/// client-side (local `_query`); the category filter is the shared
/// [selectedCategoryProvider]; cards drive the in-memory cart.
///
/// When [forInvoice] is true the page is opened from the invoice builder's
/// "Add Item" button: it shows a back button and a bottom "Add to invoice"
/// bar. The cart's own +/- Add controls do the picking; the invoice page
/// reads the cart when it regains focus, so any way back (the bar, the
/// header back, or the system back) carries the items over. The default
/// (`false`) is the normal browse tab — unchanged.
class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key, this.forInvoice = false});

  final bool forInvoice;

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
    return products.where((p) {
      if (categoryId != null && p.categoryId != categoryId) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(catalogProductsProvider);
    final categories = ref.watch(catalogCategoriesProvider);
    final selectedCategoryId = ref.watch(selectedCategoryProvider);
    final items = _filter(products, selectedCategoryId);
    final forInvoice = widget.forInvoice;
    final cartCount = forInvoice ? ref.watch(cartProvider).length : 0;

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: forInvoice
            ? _InvoiceCartBar(
                count: cartCount,
                onConfirm: cartCount > 0 ? () => context.pop() : null,
              )
            : null,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (forInvoice)
                    Padding(
                      padding: EdgeInsets.fromLTRB(4.w, 4.h, 20.w, 0),
                      child: Row(
                        children: <Widget>[
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: AppColors.textdark,
                              size: 20.sp,
                            ),
                            tooltip: 'Back',
                            onPressed: () => context.pop(),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Add Items',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
                      child: Text(
                        'Catalog',
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
                    child: items.isEmpty
                        ? _EmptyProducts(hasQuery: _query.trim().isNotEmpty)
                        : GridView.builder(
                            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 140.h),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.62,
                                  crossAxisSpacing: 12.w,
                                  mainAxisSpacing: 12.h,
                                ),
                            itemCount: items.length,
                            itemBuilder: (context, index) =>
                                CatalogProductCard(product: items[index]),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal category filter row. The leading "All" chip opens the
/// category-selection grid (matching v1); the rest toggle the shared
/// category filter.
class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.categories, required this.selectedId});

  final List<ProductCategory> categories;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Center(
              child: CategoryChip(
                label: 'All',
                icon: Icons.grid_view_rounded,
                selected: selectedId == null,
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  context.push(Routes.catalogCategories);
                },
              ),
            );
          }
          final cat = categories[index - 1];
          return Center(
            child: CategoryChip(
              label: cat.name,
              icon: categoryVisuals(cat.name).icon,
              selected: selectedId == cat.id,
              onTap: () =>
                  ref.read(selectedCategoryProvider.notifier).select(cat.id),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.inventory_2_outlined,
              size: 64.sp,
              color: AppColors.textHint,
            ),
            SizedBox(height: 16.h),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            if (hasQuery) ...<Widget>[
              SizedBox(height: 6.h),
              Text(
                'Try a different search or category.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.sp, color: AppColors.textHint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom bar shown only when the catalog is opened for the invoice: adds
/// the cart's products to the invoice draft and returns to the builder.
class _InvoiceCartBar extends StatelessWidget {
  const _InvoiceCartBar({required this.count, required this.onConfirm});

  final int count;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
          child: PrimaryButton(
            label: count == 0
                ? 'Add items using the + button'
                : 'Add $count ${count == 1 ? 'item' : 'items'} to invoice',
            leadingIcon: Icons.check_rounded,
            onPressed: onConfirm,
          ),
        ),
      ),
    );
  }
}
