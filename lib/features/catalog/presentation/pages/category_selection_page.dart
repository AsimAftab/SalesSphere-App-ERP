import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/widgets/category_visuals.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// Drill-in grid of catalog categories, reached from the catalog page's
/// "All" chip. Picking a tile sets the shared [selectedCategoryProvider]
/// and pops back to the (now filtered) catalog grid. Ported from v1's
/// `CategorySelectionScreen`.
class CategorySelectionPage extends ConsumerStatefulWidget {
  const CategorySelectionPage({super.key});

  @override
  ConsumerState<CategorySelectionPage> createState() =>
      _CategorySelectionPageState();
}

class _CategorySelectionPageState extends ConsumerState<CategorySelectionPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.catalog);
    }
  }

  void _pick(String? categoryId) {
    ref.read(selectedCategoryProvider.notifier).select(categoryId);
    FocusManager.instance.primaryFocus?.unfocus();
    _back();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(catalogCategoriesProvider);
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? categories
        : categories
              .where((c) => c.name.toLowerCase().contains(q))
              .toList(growable: false);

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
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
                  _Header(onBack: _back),
                  SizedBox(height: 20.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: PrimaryTextField(
                      controller: _searchController,
                      hintText: 'Search categories',
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
                  SizedBox(height: 16.h),
                  Expanded(
                    child: filtered.isEmpty
                        ? _EmptyCategories(query: _query.trim())
                        : GridView.builder(
                            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16.w,
                                  mainAxisSpacing: 16.h,
                                ),
                            // +1 for the leading "All Products" tile.
                            itemCount: filtered.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _CategoryTile(
                                  name: 'All Products',
                                  icon: Icons.apps,
                                  accent: AppColors.secondary,
                                  onTap: () => _pick(null),
                                );
                              }
                              final cat = filtered[index - 1];
                              final vis = categoryVisuals(cat.name);
                              return _CategoryTile(
                                name: cat.name,
                                icon: vis.icon,
                                accent: vis.accent,
                                itemCount: cat.itemCount,
                                onTap: () => _pick(cat.id),
                              );
                            },
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

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textdark, size: 20.sp),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          SizedBox(width: 12.w),
          Text(
            'Categories',
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.name,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.itemCount,
  });

  final String name;
  final IconData icon;
  final Color accent;
  final int? itemCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(icon, size: 40.sp, color: accent),
              ),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (itemCount != null) ...<Widget>[
                SizedBox(height: 4.h),
                Text(
                  '$itemCount items',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search_off, size: 64.sp, color: AppColors.textHint),
            SizedBox(height: 16.h),
            Text(
              'No categories found for "$query"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
