import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/auth/presentation/controllers/auth_controller.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/providers/beat_plan_providers.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/widgets/beat_plan_summary_card.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/widgets/beat_plan_tabs.dart';
import 'package:sales_sphere_erp/features/tracking/domain/usecases/reconcile_tracking_usecase.dart';
import 'package:sales_sphere_erp/shared/widgets/empty_state_view.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: ref.read(beatPlanTabIndexProvider));
    // Recover a tracking session that survived a reboot / OEM kill: now that
    // we're authenticated and on home, reconcile local intent with the server.
    unawaited(ref.read(reconcileTrackingUseCaseProvider).call());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(beatPlanTabIndexProvider, (previous, next) {
      if (_pageController.hasClients && _pageController.page?.round() != next) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    final beatPlansAsync = ref.watch(beatPlanControllerProvider);
    final selectedTabIndex = ref.watch(beatPlanTabIndexProvider);

    if (!_pageController.hasClients && _pageController.initialPage != selectedTabIndex) {
      _pageController.dispose();
      _pageController = PageController(initialPage: selectedTabIndex);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, ref),
              const SizedBox(height: 32),
              beatPlansAsync.when(
                data: (plans) {
                  final currentTabCount = plans.where((p) {
                    final status = p.status.toLowerCase();
                    if (selectedTabIndex == 0) {
                      return status == 'active' || status == 'pending';
                    } else {
                      return status == 'completed';
                    }
                  }).length;

                  return Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBeatPlanHeader(ref, beatPlansAsync.isLoading, currentTabCount),
                        const SizedBox(height: 20),
                        const BeatPlanTabs(),
                        const SizedBox(height: 20),
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            onPageChanged: (index) {
                              if (ref.read(beatPlanTabIndexProvider) != index) {
                                ref.read(beatPlanTabIndexProvider.notifier).setTab(index);
                              }
                            },
                            children: [
                              _buildPlanList(plans, 0),
                              _buildPlanList(plans, 1),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBeatPlanHeader(ref, true, 0),
                      const SizedBox(height: 20),
                      const BeatPlanTabs(),
                      const SizedBox(height: 40),
                      const Expanded(child: Center(child: CircularProgressIndicator())),
                    ],
                  ),
                ),
                error: (e, st) => Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBeatPlanHeader(ref, false, 0),
                      const SizedBox(height: 20),
                      const BeatPlanTabs(),
                      const SizedBox(height: 40),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Unable to load beat plans. Please check your connection and try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
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

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authControllerProvider).value;
    final firstName = authUser?.fullName.split(' ').first ?? 'User';
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hello',
              style: TextStyle(
                fontSize: 24,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w400,
              ),
            ),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstName,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOrange,
                        height: 1.1,
                      ),
                    ),
                    CustomPaint(
                      size: const Size(60, 8),
                      painter: _CurvePainter(),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Text(
                  '👋',
                  style: TextStyle(fontSize: 24),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () => context.push(Routes.profile),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textOrange, width: 2),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBeatPlanHeader(WidgetRef ref, bool isLoading, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'My Beat Plans',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Row(
          children: [
            Text(
              '$count plan${count == 1 ? '' : 's'}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => ref.read(beatPlanControllerProvider.notifier).refresh(),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.refresh,
                      color: AppColors.primary,
                      size: 20,
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlanList(List<BeatPlan> plans, int tabIndex) {
    final filteredPlans = plans.where((p) {
      final status = p.status.toLowerCase();
      if (tabIndex == 0) {
        return status == 'active' || status == 'pending';
      } else {
        return status == 'completed';
      }
    }).toList();

    // Completed tab: latest on top — order by when the plan was actually
    // completed (most recent first), falling back to the scheduled date when
    // completedAt is missing. The shared cache stream is ordered by
    // scheduledDate, which doesn't reflect completion recency.
    if (tabIndex == 1) {
      filteredPlans.sort((a, b) {
        final aDate = a.completedAt ?? a.assignedDate;
        final bDate = b.completedAt ?? b.assignedDate;
        return bDate.compareTo(aDate);
      });
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(beatPlanControllerProvider.notifier).refresh();
      },
      child: filteredPlans.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 80, top: 40),
              children: [
                EmptyStateView(
                  icon: tabIndex == 0
                      ? Icons.assignment_late_outlined
                      : Icons.assignment_turned_in_outlined,
                  title: tabIndex == 0
                      ? 'No beat plan assigned'
                      : 'No completed plans',
                  message: tabIndex == 0
                      ? 'Contact your supervisor to get assigned'
                      : "You haven't completed any beat plans yet.",
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: filteredPlans.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: BeatPlanSummaryCard(plan: filteredPlans[index]),
                );
              },
            ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width / 2, 0, size.width, size.height * 0.8);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
