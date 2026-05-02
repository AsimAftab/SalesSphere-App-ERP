import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/parties/data/parties_repository.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/shared/widgets/async_list_view.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/skeleton.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class PartiesListPage extends ConsumerStatefulWidget {
  const PartiesListPage({super.key});

  @override
  ConsumerState<PartiesListPage> createState() => _PartiesListPageState();
}

class _PartiesListPageState extends ConsumerState<PartiesListPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Party> _applySearch(List<Party> source) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.address.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final partiesAsync = ref.watch(partiesListProvider);

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: PrimaryFabButton(
          label: 'Add Party',
          onPressed: () => context.push(Routes.addParty),
        ),
        body: Stack(
          children: <Widget>[
            // Curved gradient header sits behind everything else.
            ClipPath(
              clipper: _HeaderClipper(),
              child: Container(
                height: 220.h,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppColors.headerGradientStart,
                      AppColors.headerGradientEnd,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  _PartiesAppBar(onBack: _back),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
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
                  SizedBox(height: 40.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Parties',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Expanded(
                    child: AsyncListView<Party>(
                      async: partiesAsync,
                      filter: _applySearch,
                      onRefresh: () async {
                        ref.invalidate(partiesListProvider);
                        await ref.read(partiesListProvider.future);
                      },
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 140.h),
                      itemBuilder: (context, party) => _PartyCard(
                        party: party,
                        onTap: () => context.push(
                          Routes.partyDetailPath(party.id),
                          extra: party,
                        ),
                      ),
                      skeletonItemBuilder: (_, __) => const _PartyCardSkeleton(),
                      emptyBuilder: (_) => const _EmptyState(),
                      errorBuilder: (_, __, ___) => const _ErrorState(),
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

class _PartiesAppBar extends StatelessWidget {
  const _PartiesAppBar({required this.onBack});

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
          SizedBox(width: 4.w),
          Text(
            'Parties',
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

class _PartyCard extends StatelessWidget {
  const _PartyCard({required this.party, required this.onTap});

  final Party party;
  final VoidCallback onTap;

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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 26.r,
                backgroundColor: AppColors.primary,
                child: Icon(
                  Icons.person_outline,
                  color: AppColors.textWhite,
                  size: 26.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      party.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      party.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              CircleAvatar(
                radius: 18.r,
                backgroundColor: AppColors.primary,
                child: Icon(
                  Icons.chevron_right,
                  color: AppColors.textWhite,
                  size: 22.sp,
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton mirror of [_PartyCard]. Same outer container (surface, radius,
/// shadow, padding) and matching positions/sizes for the avatar, name line,
/// address line, and chevron so the swap from skeleton → real card doesn't
/// shift the layout.
class _PartyCardSkeleton extends StatelessWidget {
  const _PartyCardSkeleton();

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
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      child: Row(
        children: <Widget>[
          // Mirrors `CircleAvatar(radius: 26.r)` — diameter 52.r.
          Skeleton.circle(size: 52.r),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Name placeholder — matches the 17.sp w600 title.
                Skeleton.line(width: 90.w, height: 13.h),
                SizedBox(height: 4.h),
                // Address placeholder — matches the 13.sp body line.
                Skeleton.line(width: 140.w, height: 10.h),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // Mirrors `CircleAvatar(radius: 18.r)` — diameter 36.r.
          Skeleton.circle(size: 36.r),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          'No parties match your search.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
          ),
        ),
      ),
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
          "Couldn't load parties. Pull to retry.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    // Diagonal sweep: shorter on the left (just behind the title), taller on
    // the right (drops to ~the search bar's lower edge) so the bubble
    // doesn't cover the whole top of the screen.
    final path = Path()
      ..lineTo(0, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.42,
        size.width,
        size.height * 0.78,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
