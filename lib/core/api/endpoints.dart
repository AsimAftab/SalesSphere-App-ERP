/// Centralised API URL paths. The base URL comes from `Env.apiBaseUrl`.
class Endpoints {
  Endpoints._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const login = '/auth/login';
  static const logout = '/auth/logout';
  static const refresh = '/auth/refresh';
  static const me = '/auth/me';
  static const session = '/auth/session';
  static const changePassword = '/auth/change-password';

  // ── Customers (parties on the mobile side) ────────────────────────────────
  static const customers = '/customers';
  static String customerById(String id) => '/customers/$id';
  static String customerImages(String id) => '/customers/$id/images';
  static String customerImageSlot(String id, int slot) =>
      '/customers/$id/images/$slot';

  // ── Customer types (party-type picker) ────────────────────────────────────
  static const customerTypes = '/customer-types';

  // ── Prospects (pre-conversion leads) ──────────────────────────────────────
  static const prospects = '/prospects';
  static String prospectById(String id) => '/prospects/$id';
  static String prospectImages(String id) => '/prospects/$id/images';
  static String prospectImageSlot(String id, int slot) =>
      '/prospects/$id/images/$slot';
  static String prospectConvert(String id) => '/prospects/$id/convert';

  // ── Prospect interest catalogue ───────────────────────────────────────────
  static const prospectCategories = '/prospect-categories';

  // ── Sites (project / outlet locations) ────────────────────────────────────
  static const sites = '/sites';
  static String siteById(String id) => '/sites/$id';
  static String siteImages(String id) => '/sites/$id/images';
  static String siteImageSlot(String id, int slot) => '/sites/$id/images/$slot';

  // ── Site reference catalogues ─────────────────────────────────────────────
  static const siteCategories = '/site-categories';
  static const siteSubOrganizations = '/site-sub-organizations';

  // ── Attendance ────────────────────────────────────────────────────────────
  static const attendanceCheckIn = '/attendance/check-in';
  static const attendanceCheckOut = '/attendance/check-out';
  static const attendanceList = '/attendance';
  static const attendanceMyMonthlyReport = '/attendance/my-monthly-report';
  static const attendanceStatusToday = '/attendance/status/today';

  // ── Leaves ────────────────────────────────────────────────────────────────
  static const leaves = '/leaves';
  static const leavesMyRequests = '/leaves/my-requests';
  static String leaveById(String id) => '/leaves/$id';

  // ── Beat plans ────────────────────────────────────────────────────────────
  static const beatPlans = '/beat-plans';
  static const beatPlanStats = '/beat-plans/stats';
  static String beatPlanById(String id) => '/beat-plans/$id';
  static String beatPlanStart(String id) => '/beat-plans/$id/start';
  static String beatPlanVisit(String id) => '/beat-plans/$id/visit';
  static String beatPlanSkip(String id) => '/beat-plans/$id/skip';
  static String beatPlanForceComplete(String id) =>
      '/beat-plans/$id/force-complete';
  static String beatPlanOptimizeRoute(String id) =>
      '/beat-plans/$id/optimize-route';
  static String beatPlanStopImages(String beatPlanId, String stopId) =>
      '/beat-plans/$beatPlanId/stops/$stopId/images';
  static String beatPlanStopImageSlot(
    String beatPlanId,
    String stopId,
    int slot,
  ) =>
      '/beat-plans/$beatPlanId/stops/$stopId/images/$slot';

  // ── Live tracking (REST is read-only; live writes go over the socket) ─────
  static const trackingActive = '/tracking/active';
  static const trackingCompleted = '/tracking/completed';
  static String trackingByBeatPlan(String beatPlanId) =>
      '/tracking/$beatPlanId';
  static String trackingCurrentLocation(String beatPlanId) =>
      '/tracking/$beatPlanId/current-location';
  static String trackingHistory(String beatPlanId) =>
      '/tracking/$beatPlanId/history';
  static String trackingSessionBreadcrumbs(String sessionId) =>
      '/tracking/sessions/$sessionId/breadcrumbs';
  static String trackingSessionSummary(String sessionId) =>
      '/tracking/sessions/$sessionId/summary';

  // ── Tour plans ────────────────────────────────────────────────────────────
  static const tourPlans = '/tour-plans';
  static String tourPlanById(String id) => '/tour-plans/$id';
  static String tourPlanStatus(String id) => '/tour-plans/$id/status';

  // ── Odometer ──────────────────────────────────────────────────────────────
  static const odometerStart = '/odometer/start';
  static const odometerStop = '/odometer/stop';
  static const odometerStatusToday = '/odometer/status/today';
  static const odometerMyMonthlyReport = '/odometer/my-monthly-report';
  static String odometerById(String id) => '/odometer/$id';

  // ── Unplanned visits ──────────────────────────────────────────────────────
  static const unplannedVisitStart = '/unplanned-visits/start';
  static const unplannedVisitStop = '/unplanned-visits/stop';
  static const unplannedVisitsStatusToday = '/unplanned-visits/status/today';
  static String unplannedVisitById(String id) => '/unplanned-visits/$id';

  // ── Collections ───────────────────────────────────────────────────────────
  static const collections = '/collections';

  // ── Expense claims ────────────────────────────────────────────────────────
  static const expenseClaims = '/expense-claims';
  static const expenseClaimsMyRequests = '/expense-claims/my-requests';
  static String expenseClaimById(String id) => '/expense-claims/$id';
  static String expenseClaimImages(String id) => '/expense-claims/$id/images';
  static String expenseClaimImageSlot(String id, int slot) =>
      '/expense-claims/$id/images/$slot';

  // ── Expense-claim category catalogue (org-managed picker list) ────────────
  static const expenseClaimCategories = '/expense-claim-categories';

  // ── Miscellaneous work ────────────────────────────────────────────────────
  static const miscellaneousWork = '/miscellaneous-work';
  static String miscellaneousWorkById(String id) => '/miscellaneous-work/$id';
  static String miscellaneousWorkImages(String id) =>
      '/miscellaneous-work/$id/images';
  static String miscellaneousWorkImageSlot(String id, int slot) =>
      '/miscellaneous-work/$id/images/$slot';

  // ── Notes ─────────────────────────────────────────────────────────────────
  static const notes = '/notes';
  static String noteById(String id) => '/notes/$id';
  static String noteImages(String id) => '/notes/$id/images';
  static String noteImageSlot(String id, int slot) => '/notes/$id/images/$slot';

  // ── Profile ───────────────────────────────────────────────────────────────
  static const profile = '/profile';

  // ── Devices (push tokens) ─────────────────────────────────────────────────
  static const deviceRegister = '/devices/register';
}
