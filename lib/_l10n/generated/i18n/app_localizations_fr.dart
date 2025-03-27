// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get onboardingScreenTitle => 'Bienvenue';

  @override
  String get onboardingCreateWalletButtonLabel => 'Créer un wallet';

  @override
  String get onboardingRecoverWalletButtonLabel => 'Restaurer un wallet';

  @override
  String get settingsScreenTitle => 'Paramètres';

  @override
  String get testnetModeSettingsLabel => 'Mode Testnet';

  @override
  String get satsBitcoinUnitSettingsLabel => 'Afficher l\'unité en sats';

  @override
  String get pinCodeSettingsLabel => 'Code PIN';

  @override
  String get languageSettingsLabel => 'Langue';

  @override
  String get fiatCurrencySettingsLabel => 'Devise fiduciaire';

  @override
  String get languageSettingsScreenTitle => 'Langue';
}
