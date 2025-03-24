// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get onboardingScreenTitle => 'Welcome';

  @override
  String get onboardingCreateWalletButtonLabel => 'Create wallet';

  @override
  String get onboardingRecoverWalletButtonLabel => 'Recover wallet';

  @override
  String get settingsScreenTitle => 'Settings';

  @override
  String get testnetModeSettingsLabel => 'Testnet mode';

  @override
  String get satsBitcoinUnitSettingsLabel => 'Display unit in sats';

  @override
  String get pinCodeSettingsLabel => 'PIN code';

  @override
  String get languageSettingsLabel => 'Language';

  @override
  String get fiatCurrencySettingsLabel => 'Fiat currency';

  @override
  String get languageSettingsScreenTitle => 'Language';
}
