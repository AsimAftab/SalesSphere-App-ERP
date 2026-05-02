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
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/presentation/pages/add_party_page.dart';
import 'package:sales_sphere_erp/features/parties/presentation/pages/parties_list_page.dart';
import 'package:sales_sphere_erp/features/parties/presentation/pages/edit_party_detail_page.dart';
import 'package:sales_sphere_erp/features/profile/presentation/pages/profile_page.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';
import 'package:sales_sphere_erp/features/prospects/presentation/pages/add_prospect_page.dart';
import 'package:sales_sphere_erp/features/prospects/presentation/pages/edit_prospect_detail_page.dart';
import 'package:sales_sphere_erp/features/prospects/presentation/pages/prospects_list_page.dart';
import 'package:sales_sphere_erp/features/splash/splash_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Eagerly instantiate the auth controller so its startup resolution runs.
  // Without this read, authStateProvider stays at AuthStatus.unknown forever
  // and the redirect parks every navigation on the splash page.
  ref.read(authControllerProvider);

  final refresh = RouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.prospects,
    debugLogDiagnostics: true,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;

      // TEMP: preview the parties + prospects UI without going through
      // auth. Remove this bypass once the auth-gated entry point is
      // wired up again.
      if (loc == Routes.parties ||
          loc == Routes.addParty ||
          loc.startsWith('/parties/detail/') ||
          loc == Routes.prospects ||
          loc == Routes.addProspect ||
          loc.startsWith('/prospects/detail/')) {
        return null;
      }

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
      GoRoute(
        path: Routes.parties,
        name: Routes.partiesName,
        builder: (_, __) => const PartiesListPage(),
      ),
      GoRoute(
        path: Routes.addParty,
        name: Routes.addPartyName,
        builder: (_, __) => const AddPartyPage(),
      ),
      GoRoute(
        path: Routes.partyDetail,
        name: Routes.partyDetailName,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          return EditPartyDetailPage(
            id: id,
            initial: extra is Party ? extra : null,
          );
        },
      ),
      GoRoute(
        path: Routes.prospects,
        name: Routes.prospectsName,
        builder: (_, __) => const ProspectsListPage(),
      ),
      GoRoute(
        path: Routes.addProspect,
        name: Routes.addProspectName,
        builder: (_, __) => const AddProspectPage(),
      ),
      GoRoute(
        path: Routes.prospectDetail,
        name: Routes.prospectDetailName,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          return EditProspectDetailPage(
            id: id,
            initial: extra is Prospect ? extra : null,
          );
        },
      ),
    ],
  );
});
