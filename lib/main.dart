import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sales_sphere_erp/app.dart';
import 'package:sales_sphere_erp/core/config/env.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/providers/app_observer.dart';
import 'package:sales_sphere_erp/core/providers/shared_prefs_provider.dart';
import 'package:sales_sphere_erp/core/sync/mutation_handler_overrides.dart';
import 'package:sales_sphere_erp/features/auth/presentation/controllers/auth_controller.dart';
import 'package:sales_sphere_erp/features/tracking/service/tracking_service.dart';

Future<void> bootstrap() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final env = Env.initialise();

      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
      ]);

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: AppColors.surface,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      );

      // Create the tracking notification channel + register the foreground
      // service (autoStart:false — it only runs once a rep starts a beat plan).
      await configureTrackingService();

      final sharedPrefs = await SharedPreferences.getInstance();

      Future<void> launch() async {
        runApp(
          ProviderScope(
            overrides: [
              sharedPrefsProvider.overrideWithValue(sharedPrefs),
              ...authProviderOverrides,
              // Single merged registration of every feature's MutationHandler
              // (parties + beat-plan visit/skip). See mutation_handler_overrides.
              mutationHandlersOverride,
            ],
            observers: <ProviderObserver>[AppProviderObserver()],
            child: const SalesSphereApp(),
          ),
        );
      }

      if (env.sentryDsn.isEmpty) {
        FlutterError.onError = (details) {
          FlutterError.presentError(details);
        };
        await launch();
      } else {
        await SentryFlutter.init(
          (options) {
            options
              ..dsn = env.sentryDsn
              ..tracesSampleRate = kDebugMode ? 1.0 : 0.2
              ..environment = env.flavor.name
              ..debug = kDebugMode
              ..attachStacktrace = true;
          },
          appRunner: launch,
        );
      }
    },
    (error, stack) {
      debugPrint('Uncaught zone error: $error\n$stack');
      Sentry.captureException(error, stackTrace: stack);
    },
  );
}
