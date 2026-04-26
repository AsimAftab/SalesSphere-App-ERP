// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Nepali (`ne`).
class AppL10nNe extends AppL10n {
  AppL10nNe([String locale = 'ne']) : super(locale);

  @override
  String get appTitle => 'SalesSphere';

  @override
  String get loginTitle => 'SalesSphere — साइन इन';

  @override
  String get loginEmailLabel => 'इमेल';

  @override
  String get loginPasswordLabel => 'पासवर्ड';

  @override
  String get loginEmailRequired => 'इमेल आवश्यक छ';

  @override
  String get loginPasswordRequired => 'पासवर्ड आवश्यक छ';

  @override
  String get loginSubmit => 'साइन इन';

  @override
  String get loginWelcome => 'स्वागत छ';

  @override
  String get biometricTitle => 'अनलक';

  @override
  String get biometricInstruction =>
      'SalesSphere अनलक गर्न औंलाछाप वा अनुहार प्रयोग गर्नुहोस्।';

  @override
  String get biometricUnlock => 'अनलक';

  @override
  String get biometricUsePassword => 'पासवर्ड प्रयोग गर्नुहोस्';

  @override
  String get navHome => 'गृह';

  @override
  String get navAttendance => 'हाजिरी';

  @override
  String get navProfile => 'प्रोफाइल';

  @override
  String get profileSignOut => 'साइन आउट';

  @override
  String get syncIdle => 'अद्यावधिक';

  @override
  String get syncSyncing => 'सिङ्क हुँदै…';

  @override
  String get syncOffline => 'अफलाइन — पुनः जडान भएपछि सिङ्क हुनेछ';

  @override
  String syncPending(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString परिवर्तनहरू बाँकी छन्',
      one: '१ परिवर्तन बाँकी छ',
      zero: 'कुनै परिवर्तनहरू छैनन्',
    );
    return '$_temp0';
  }
}
