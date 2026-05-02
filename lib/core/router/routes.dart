class Routes {
  Routes._();

  static const splash = '/';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const biometric = '/biometric';

  static const home = '/home';
  static const attendance = '/attendance';
  static const profile = '/profile';
  static const parties = '/parties';
  static const addParty = '/parties/add';
  static const partyDetail = '/parties/detail/:id';

  static String partyDetailPath(String id) => '/parties/detail/$id';

  static const prospects = '/prospects';
  static const addProspect = '/prospects/add';
  static const prospectDetail = '/prospects/detail/:id';

  static String prospectDetailPath(String id) => '/prospects/detail/$id';

  static const splashName = 'splash';
  static const loginName = 'login';
  static const forgotPasswordName = 'forgotPassword';
  static const biometricName = 'biometric';
  static const homeName = 'home';
  static const attendanceName = 'attendance';
  static const profileName = 'profile';
  static const partiesName = 'parties';
  static const addPartyName = 'addParty';
  static const partyDetailName = 'partyDetail';
  static const prospectsName = 'prospects';
  static const addProspectName = 'addProspect';
  static const prospectDetailName = 'prospectDetail';
}
