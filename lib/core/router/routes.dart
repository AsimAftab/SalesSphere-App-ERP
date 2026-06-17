class Routes {
  Routes._();

  static const splash = '/';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';

  static const home = '/home';
  static const catalog = '/catalog';
  static const billing = '/billing';
  static const customers = '/customers';
  static const more = '/more';
  static const profile = '/profile';
  static const settings = '/settings';
  static const changePassword = '/change-password';
  static const parties = '/parties';
  static const addParty = '/parties/add';
  static const partyDetail = '/parties/detail/:id';

  static String partyDetailPath(String id) => '/parties/detail/$id';

  static const prospects = '/prospects';
  static const addProspect = '/prospects/add';
  static const prospectDetail = '/prospects/detail/:id';

  static const odometer = '/odometer';
  static const odometerHistory = '/odometer/history';
  static const odometerTripDetail = '/odometer/trips/:id';

  static String odometerTripDetailPath(String id) => '/odometer/trips/$id';

  static const unplannedVisits = '/unplanned-visits';
  static const unplannedVisitDetail = '/unplanned-visits/detail/:id';

  static String unplannedVisitDetailPath(String id) =>
      '/unplanned-visits/detail/$id';

  static String prospectDetailPath(String id) => '/prospects/detail/$id';

  static const sites = '/sites';
  static const addSite = '/sites/add';
  static const siteDetail = '/sites/detail/:id';

  static String siteDetailPath(String id) => '/sites/detail/$id';

  static const notes = '/notes';
  static const addNote = '/notes/add';
  static const noteDetail = '/notes/detail/:id';

  static String noteDetailPath(String id) => '/notes/detail/$id';

  static const attendance = '/attendance';
  static const attendanceDetails = '/attendance/details';
  static const attendanceDayDetail = '/attendance/:date';

  static String attendanceDayDetailPath(String iso) => '/attendance/$iso';

  static const miscellaneousWorks = '/miscellaneous-work';
  static const addMiscellaneousWork = '/miscellaneous-work/add';
  static const miscellaneousWorkDetail = '/miscellaneous-work/detail/:id';

  static String miscellaneousWorkDetailPath(String id) =>
      '/miscellaneous-work/detail/$id';

  static const leaves = '/leaves';
  static const addLeave = '/leaves/add';
  static const leaveDetail = '/leaves/detail/:id';

  static String leaveDetailPath(String id) => '/leaves/detail/$id';

  static const tourPlans = '/tour-plans';
  static const addTourPlan = '/tour-plans/add';
  static const tourPlanDetail = '/tour-plans/detail/:id';
  static String tourPlanDetailPath(String id) => '/tour-plans/detail/$id';

  static const beatPlanDetail = '/beat-plans/detail/:id';
  static String beatPlanDetailPath(String id) => '/beat-plans/detail/${Uri.encodeComponent(id)}';

  static const splashName = 'splash';
  static const loginName = 'login';
  static const forgotPasswordName = 'forgotPassword';
  static const homeName = 'home';
  static const catalogName = 'catalog';
  static const billingName = 'billing';
  static const customersName = 'customers';
  static const moreName = 'more';
  static const profileName = 'profile';
  static const settingsName = 'settings';
  static const changePasswordName = 'changePassword';
  static const partiesName = 'parties';
  static const addPartyName = 'addParty';
  static const partyDetailName = 'partyDetail';
  static const prospectsName = 'prospects';
  static const addProspectName = 'addProspect';
  static const prospectDetailName = 'prospectDetail';
  static const sitesName = 'sites';
  static const addSiteName = 'addSite';
  static const siteDetailName = 'siteDetail';
  static const notesName = 'notes';
  static const addNoteName = 'addNote';
  static const noteDetailName = 'noteDetail';
  static const odometerName = 'odometer';
  static const odometerHistoryName = 'odometerHistory';
  static const odometerTripDetailName = 'odometerTripDetail';
  static const unplannedVisitsName = 'unplannedVisits';
  static const unplannedVisitDetailName = 'unplannedVisitDetail';
  static const attendanceName = 'attendance';
  static const attendanceDetailsName = 'attendanceDetails';
  static const attendanceDayDetailName = 'attendanceDayDetail';
  static const miscellaneousWorksName = 'miscellaneousWorks';
  static const addMiscellaneousWorkName = 'addMiscellaneousWork';
  static const miscellaneousWorkDetailName = 'miscellaneousWorkDetail';
  static const leavesName = 'leaves';
  static const addLeaveName = 'addLeave';
  static const leaveDetailName = 'leaveDetail';
  static const tourPlansName = 'tourPlans';
  static const addTourPlanName = 'addTourPlan';
  static const tourPlanDetailName = 'tourPlanDetail';
  static const beatPlanDetailName = 'beatPlanDetail';
}
