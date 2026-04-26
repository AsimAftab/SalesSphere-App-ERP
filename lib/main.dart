import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:sales_sphere_erp/app.dart';
import 'package:sales_sphere_erp/core/config/env.dart';
import 'package:sales_sphere_erp/core/providers/app_observer.dart';
import 'package:sales_sphere_erp/features/auth/auth_controller.dart';

Future<void> bootstrap() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final env = Env.initialise();

      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
      ]);

      final Future<void> Function() launch = () async {
        runApp(
          ProviderScope(
            overrides: [...authProviderOverrides],
            observers: <ProviderObserver>[AppProviderObserver()],
            child: const SalesSphereApp(),
          ),
        );
      };

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
