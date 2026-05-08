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
  static const parties = '/parties';
  static const addParty = '/parties/add';
  static const partyDetail = '/parties/detail/:id';

  static String partyDetailPath(String id) => '/parties/detail/$id';

  static const prospects = '/prospects';
  static const addProspect = '/prospects/add';
  static const prospectDetail = '/prospects/detail/:id';

  static String prospectDetailPath(String id) => '/prospects/detail/$id';

  static const sites = '/sites';
  static const addSite = '/sites/add';
  static const siteDetail = '/sites/detail/:id';

  static String siteDetailPath(String id) => '/sites/detail/$id';

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
  static const partiesName = 'parties';
  static const addPartyName = 'addParty';
  static const partyDetailName = 'partyDetail';
  static const prospectsName = 'prospects';
  static const addProspectName = 'addProspect';
  static const prospectDetailName = 'prospectDetail';
  static const sitesName = 'sites';
  static const addSiteName = 'addSite';
  static const siteDetailName = 'siteDetail';
}
