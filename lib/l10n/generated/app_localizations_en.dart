// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SalesSphere';

  @override
  String get loginTitle => 'SalesSphere — Sign in';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginEmailRequired => 'Email required';

  @override
  String get loginPasswordRequired => 'Password required';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginWelcome => 'Welcome back';

  @override
  String get biometricTitle => 'Unlock';

  @override
  String get biometricInstruction =>
      'Use your fingerprint or face to unlock SalesSphere.';

  @override
  String get biometricUnlock => 'Unlock';

  @override
  String get biometricUsePassword => 'Use password instead';

  @override
  String get navHome => 'Home';

  @override
  String get navAttendance => 'Attendance';

  @override
  String get navProfile => 'Profile';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get syncIdle => 'Up to date';

  @override
  String get syncSyncing => 'Syncing…';

  @override
  String get syncOffline => 'Offline — changes will sync when you reconnect';

  @override
  String syncPending(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString pending changes',
      one: '1 pending change',
      zero: 'No pending changes',
    );
    return '$_temp0';
  }
}
