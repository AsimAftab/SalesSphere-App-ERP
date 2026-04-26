import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/router/app_router.dart';
import 'package:sales_sphere_erp/core/theme/app_theme.dart';
import 'package:sales_sphere_erp/l10n/generated/app_localizations.dart';

class SalesSphereApp extends ConsumerWidget {
  const SalesSphereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return ScreenUtilInit(
      designSize: const Size(360, 800),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'SalesSphere',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          routerConfig: router,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          builder: (context, child) {
            final clamped = MediaQuery.textScalerOf(context)
                .clamp(minScaleFactor: 0.8, maxScaleFactor: 1.3);
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
