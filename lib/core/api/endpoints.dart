/// Centralised API URL paths. The base URL comes from `Env.apiBaseUrl`.
class Endpoints {
  Endpoints._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const login = '/auth/login';
  static const logout = '/auth/logout';
  static const refresh = '/auth/refresh';
  static const me = '/auth/me';
  static const session = '/auth/session';

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
  static String siteImageSlot(String id, int slot) =>
      '/sites/$id/images/$slot';

  // ── Site reference catalogues ─────────────────────────────────────────────
  static const siteCategories = '/site-categories';
  static const siteSubOrganizations = '/site-sub-organizations';

  // ── Attendance ────────────────────────────────────────────────────────────
  static const attendanceCheckIn = '/attendance/check-in';
  static const attendanceCheckOut = '/attendance/check-out';
  static const attendanceList = '/attendance';

  // ── Beat plans ────────────────────────────────────────────────────────────
  static const beatPlans = '/beat-plans';
  static String beatPlanById(String id) => '/beat-plans/$id';
  static String beatPlanVisits(String id) => '/beat-plans/$id/visits';

  // ── Tour plans ────────────────────────────────────────────────────────────
  static const tourPlans = '/tour-plans';

  // ── Odometer ──────────────────────────────────────────────────────────────
  static const odometerLogs = '/odometer/logs';

  // ── Collections ───────────────────────────────────────────────────────────
  static const collections = '/collections';

  // ── Expense claims ────────────────────────────────────────────────────────
  static const expenseClaims = '/expense-claims';

  // ── Miscellaneous work ────────────────────────────────────────────────────
  static const miscellaneousWork = '/miscellaneous-work';

  // ── Profile ───────────────────────────────────────────────────────────────
  static const profile = '/profile';

  // ── Devices (push tokens) ─────────────────────────────────────────────────
  static const deviceRegister = '/devices/register';
}
