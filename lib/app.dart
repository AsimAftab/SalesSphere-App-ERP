import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/router/app_router.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/core/sync/sync_scheduler.dart';
import 'package:sales_sphere_erp/core/theme/app_theme.dart';
import 'package:sales_sphere_erp/features/tracking/presentation/controllers/tracking_controller.dart';
import 'package:sales_sphere_erp/features/tracking/service/tracking_service.dart';
import 'package:sales_sphere_erp/l10n/generated/app_localizations.dart';

class SalesSphereApp extends ConsumerWidget {
  const SalesSphereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Start the outbox drain scheduler on first build. The Notifier's
    // build() attaches a 30s periodic timer and a connectivity listener;
    // this watch keeps it alive for the app's lifetime. Disposal hooks
    // are wired in the scheduler itself.
    ref.watch(syncSchedulerProvider);

    // Keep the tracking controller alive for the whole app so it always
    // catches the service's lifecycle events (force-stop, summary) even
    // between screens.
    ref.watch(trackingControllerProvider);

    // Route a tap on the persistent tracking notification to the plan detail.
    trackingNotificationTapHandler =
        (beatPlanId) => router.push(Routes.beatPlanDetailPath(beatPlanId));

    return ScreenUtilInit(
      designSize: const Size(360, 800),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'SalesSphere',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
          scrollBehavior: const _NoGlowScrollBehavior(),
          routerConfig: router,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          builder: (context, child) {
            final clamped = MediaQuery.textScalerOf(
              context,
            ).clamp(minScaleFactor: 0.8, maxScaleFactor: 1.3);
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: clamped),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}

/// Removes the Android overscroll glow app-wide. The default
/// `GlowingOverscrollIndicator` paints a rectangular tint that bleeds past
/// rounded card corners.
class _NoGlowScrollBehavior extends MaterialScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
