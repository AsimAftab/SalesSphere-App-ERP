import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/auth/auth_state.dart';
import 'package:sales_sphere_erp/core/router/router_refresh.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/core/router/shell_scaffold.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/pages/attendance_page.dart';
import 'package:sales_sphere_erp/features/auth/auth_controller.dart';
import 'package:sales_sphere_erp/features/auth/presentation/pages/biometric_unlock_page.dart';
import 'package:sales_sphere_erp/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:sales_sphere_erp/features/auth/presentation/pages/login_page.dart';
import 'package:sales_sphere_erp/features/home/presentation/pages/home_page.dart';
import 'package:sales_sphere_erp/features/profile/presentation/pages/profile_page.dart';
import 'package:sales_sphere_erp/features/splash/splash_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Eagerly instantiate the auth controller so its startup resolution runs.
  // Without this read, authStateProvider stays at AuthStatus.unknown forever
  // and the redirect parks every navigation on the splash page.
  ref.read(authControllerProvider);

  final refresh = RouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;

      // Unknown auth state → splash, unless we're already on splash.
      if (auth.status == AuthStatus.unknown) {
        return loc == Routes.splash ? null : Routes.splash;
      }

      switch (auth.status) {
        case AuthStatus.unauthenticated:
          final inAuthZone =
              loc == Routes.login || loc == Routes.forgotPassword;
          return inAuthZone ? null : Routes.login;
        case AuthStatus.awaitingBiometric:
          return loc == Routes.biometric ? null : Routes.biometric;
        case AuthStatus.authenticated:
          final inAuthZone = loc == Routes.login ||
              loc == Routes.forgotPassword ||
              loc == Routes.biometric ||
              loc == Routes.splash;
          return inAuthZone ? Routes.home : null;
        case AuthStatus.unknown:
          return null;
      }
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.splash,
        name: Routes.splashName,
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: Routes.login,
        name: Routes.loginName,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        name: Routes.forgotPasswordName,
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: Routes.biometric,
        name: Routes.biometricName,
        builder: (_, __) => const BiometricUnlockPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: Routes.home,
            name: Routes.homeName,
            builder: (_, __) => const HomePage(),
          ),
          GoRoute(
            path: Routes.attendance,
            name: Routes.attendanceName,
            builder: (_, __) => const AttendancePage(),
          ),
          GoRoute(
            path: Routes.profile,
            name: Routes.profileName,
            builder: (_, __) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
});
