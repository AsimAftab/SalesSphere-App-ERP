/// Centralised API URL paths. The base URL comes from `Env.apiBaseUrl`.
class Endpoints {
  Endpoints._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const login = '/auth/login';
  static const logout = '/auth/logout';
  static const refresh = '/auth/refresh';
  static const me = '/auth/me';

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
