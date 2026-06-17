import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/auth/auth_state.dart';
import 'package:sales_sphere_erp/core/router/router_refresh.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/core/router/shell_scaffold.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/pages/attendance_day_detail_page.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/pages/attendance_details_page.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/pages/attendance_home_page.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/pages/beat_plan_detail_page.dart';
import 'package:sales_sphere_erp/features/auth/presentation/controllers/auth_controller.dart';
import 'package:sales_sphere_erp/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:sales_sphere_erp/features/auth/presentation/pages/login_page.dart';
import 'package:sales_sphere_erp/features/billing/presentation/pages/billing_page.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/pages/catalog_page.dart';
import 'package:sales_sphere_erp/features/catalog/presentation/pages/category_selection_page.dart';
import 'package:sales_sphere_erp/features/customers/presentation/pages/customers_hub_page.dart';
import 'package:sales_sphere_erp/features/home/presentation/pages/home_page.dart';
import 'package:sales_sphere_erp/features/leaves/domain/leave.dart';
import 'package:sales_sphere_erp/features/leaves/presentation/pages/add_leave_page.dart';
import 'package:sales_sphere_erp/features/leaves/presentation/pages/edit_leave_detail_page.dart';
import 'package:sales_sphere_erp/features/leaves/presentation/pages/leaves_list_page.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/domain/miscellaneous_work.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/presentation/pages/add_miscellaneous_work_page.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/presentation/pages/edit_miscellaneous_work_detail_page.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/presentation/pages/miscellaneous_work_list_page.dart';
import 'package:sales_sphere_erp/features/more/presentation/pages/more_page.dart';
import 'package:sales_sphere_erp/features/notes/domain/note.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/pages/odometer_history_page.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/pages/odometer_home_page.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/pages/odometer_trip_detail_page.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/pages/unplanned_visit_detail_page.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/pages/unplanned_visits_home_page.dart';
import 'package:sales_sphere_erp/features/notes/presentation/pages/add_note_page.dart';
import 'package:sales_sphere_erp/features/notes/presentation/pages/edit_note_detail_page.dart';
import 'package:sales_sphere_erp/features/notes/presentation/pages/notes_list_page.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/presentation/pages/add_party_page.dart';
import 'package:sales_sphere_erp/features/parties/presentation/pages/edit_party_detail_page.dart';
import 'package:sales_sphere_erp/features/parties/presentation/pages/parties_list_page.dart';
import 'package:sales_sphere_erp/features/profile/presentation/pages/profile_page.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';
import 'package:sales_sphere_erp/features/prospects/presentation/pages/add_prospect_page.dart';
import 'package:sales_sphere_erp/features/prospects/presentation/pages/edit_prospect_detail_page.dart';
import 'package:sales_sphere_erp/features/prospects/presentation/pages/prospects_list_page.dart';
import 'package:sales_sphere_erp/features/settings/presentation/pages/change_password_page.dart';
import 'package:sales_sphere_erp/features/settings/presentation/pages/settings_page.dart';
import 'package:sales_sphere_erp/features/sites/domain/site.dart';
import 'package:sales_sphere_erp/features/sites/presentation/pages/add_site_page.dart';
import 'package:sales_sphere_erp/features/sites/presentation/pages/edit_site_detail_page.dart';
import 'package:sales_sphere_erp/features/sites/presentation/pages/sites_list_page.dart';
import 'package:sales_sphere_erp/features/splash/splash_page.dart';
import 'package:sales_sphere_erp/features/tour_plans/domain/tour_plan.dart';
import 'package:sales_sphere_erp/features/tour_plans/presentation/pages/add_tour_plan_page.dart';
import 'package:sales_sphere_erp/features/tour_plans/presentation/pages/edit_tour_plan_detail_page.dart';
import 'package:sales_sphere_erp/features/tour_plans/presentation/pages/tour_plans_list_page.dart';

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

      // Unknown auth state → splash, unless we're already there.
      if (auth.status == AuthStatus.unknown) {
        return loc == Routes.splash ? null : Routes.splash;
      }

      switch (auth.status) {
        case AuthStatus.unauthenticated:
          final inAuthZone =
              loc == Routes.login || loc == Routes.forgotPassword;
          return inAuthZone ? null : Routes.login;
        case AuthStatus.authenticated:
          final inAuthZone =
              loc == Routes.login ||
              loc == Routes.forgotPassword ||
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
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: Routes.home,
            name: Routes.homeName,
            builder: (_, __) => const HomePage(),
          ),
          GoRoute(
            path: Routes.catalog,
            name: Routes.catalogName,
            builder: (_, __) => const CatalogPage(),
          ),
          GoRoute(
            path: Routes.billing,
            name: Routes.billingName,
            builder: (_, __) => const BillingPage(),
          ),
          GoRoute(
            path: Routes.customers,
            name: Routes.customersName,
            builder: (_, __) => const CustomersHubPage(),
          ),
          GoRoute(
            path: Routes.more,
            name: Routes.moreName,
            builder: (_, __) => const MorePage(),
          ),
          GoRoute(
            path: Routes.settings,
            name: Routes.settingsName,
            builder: (_, __) => const SettingsPage(),
          ),
        ],
      ),
      // Pushed full-screen over the shell (no bottom nav) — reached from
      // the catalog page's "All" chip.
      GoRoute(
        path: Routes.catalogCategories,
        name: Routes.catalogCategoriesName,
        builder: (_, __) => const CategorySelectionPage(),
      ),
      GoRoute(
        path: Routes.profile,
        name: Routes.profileName,
        builder: (_, __) => const ProfilePage(),
      ),
      GoRoute(
        path: Routes.changePassword,
        name: Routes.changePasswordName,
        builder: (_, __) => const ChangePasswordPage(),
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
      GoRoute(
        path: Routes.sites,
        name: Routes.sitesName,
        builder: (_, __) => const SitesListPage(),
      ),
      GoRoute(
        path: Routes.addSite,
        name: Routes.addSiteName,
        builder: (_, __) => const AddSitePage(),
      ),
      GoRoute(
        path: Routes.siteDetail,
        name: Routes.siteDetailName,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          return EditSiteDetailPage(
            id: id,
            initial: extra is Site ? extra : null,
          );
        },
      ),
      GoRoute(
        path: Routes.notes,
        name: Routes.notesName,
        builder: (_, __) => const NotesListPage(),
      ),
      GoRoute(
        path: Routes.addNote,
        name: Routes.addNoteName,
        builder: (_, __) => const AddNotePage(),
      ),
      GoRoute(
        path: Routes.noteDetail,
        name: Routes.noteDetailName,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          return EditNoteDetailPage(
            id: id,
            initial: extra is Note ? extra : null,
          );
        },
      ),
      GoRoute(
        path: Routes.attendance,
        name: Routes.attendanceName,
        builder: (_, __) => const AttendanceHomePage(),
      ),
      GoRoute(
        path: Routes.odometer,
        name: Routes.odometerName,
        builder: (_, __) => const OdometerHomePage(),
      ),
      GoRoute(
        path: Routes.odometerHistory,
        name: Routes.odometerHistoryName,
        builder: (_, __) => const OdometerHistoryPage(),
      ),
      GoRoute(
        path: Routes.odometerTripDetail,
        name: Routes.odometerTripDetailName,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return OdometerTripDetailPage(tripId: id);
        },
      ),
      GoRoute(
        path: Routes.unplannedVisits,
        name: Routes.unplannedVisitsName,
        builder: (_, __) => const UnplannedVisitsHomePage(),
      ),
      GoRoute(
        path: Routes.unplannedVisitDetail,
        name: Routes.unplannedVisitDetailName,
        builder: (context, state) =>
            UnplannedVisitDetailPage(id: state.pathParameters['id']!),
      ),
      // Literal `/attendance/details` MUST be declared before the
      // `:date` route — go_router resolves on declaration order, and
      // otherwise `details` would bind to the parameter slot and try to
      // parse as a date (and crash).
      GoRoute(
        path: Routes.attendanceDetails,
        name: Routes.attendanceDetailsName,
        builder: (_, __) => const AttendanceDetailsPage(),
      ),
      GoRoute(
        path: Routes.attendanceDayDetail,
        name: Routes.attendanceDayDetailName,
        builder: (context, state) {
          final iso = state.pathParameters['date']!;
          final parsed = DateTime.tryParse(iso);
          return parsed == null
              ? const AttendanceDayDetailPage(date: null)
              : AttendanceDayDetailPage(date: parsed);
        },
      ),
      GoRoute(
        path: Routes.miscellaneousWorks,
        name: Routes.miscellaneousWorksName,
        builder: (_, __) => const MiscellaneousWorkListPage(),
      ),
      GoRoute(
        path: Routes.addMiscellaneousWork,
        name: Routes.addMiscellaneousWorkName,
        builder: (_, __) => const AddMiscellaneousWorkPage(),
      ),
      GoRoute(
        path: Routes.miscellaneousWorkDetail,
        name: Routes.miscellaneousWorkDetailName,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          return EditMiscellaneousWorkDetailPage(
            id: id,
            initial: extra is MiscellaneousWork ? extra : null,
          );
        },
      ),
      GoRoute(
        path: Routes.leaves,
        name: Routes.leavesName,
        builder: (_, __) => const LeavesListPage(),
      ),
      GoRoute(
        path: Routes.addLeave,
        name: Routes.addLeaveName,
        builder: (_, __) => const AddLeavePage(),
      ),
      GoRoute(
        path: Routes.leaveDetail,
        name: Routes.leaveDetailName,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          return EditLeaveDetailPage(
            id: id,
            initial: extra is Leave ? extra : null,
          );
        },
      ),
      GoRoute(
        path: Routes.tourPlans,
        name: Routes.tourPlansName,
        builder: (_, __) => const TourPlansListPage(),
      ),
      GoRoute(
        path: Routes.addTourPlan,
        name: Routes.addTourPlanName,
        builder: (_, __) => const AddTourPlanPage(),
      ),
      GoRoute(
        path: Routes.tourPlanDetail,
        name: Routes.tourPlanDetailName,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          return EditTourPlanDetailPage(
            id: id,
            initial: extra is TourPlan ? extra : null,
          );
        },
      ),
      GoRoute(
        path: Routes.beatPlanDetail,
        name: Routes.beatPlanDetailName,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BeatPlanDetailPage(id: id);
        },
      ),
    ],
  );
});
