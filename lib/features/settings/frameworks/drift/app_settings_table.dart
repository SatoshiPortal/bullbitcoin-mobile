import 'package:bb_mobile/features/settings/frameworks/drift/app_settings_db_enums.dart';
import 'package:drift/drift.dart';

@DataClassName('AppSettingsRow')
class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Currency settings
  TextColumn get fiatCurrencyCode => text().withDefault(
    const Constant('CAD'),
  )(); // Store ISO 4217 code like USD, EUR, etc.
  TextColumn get bitcoinUnit =>
      textEnum<BitcoinUnitDb>().withDefault(const Constant('btc'))();

  // Display settings
  TextColumn get languageTag => text().withDefault(
    const Constant('en-US'),
  )(); // Store BCP-47 language tag (en-US, fr-FR, nl-BE, etc.)
  TextColumn get themeMode =>
      textEnum<ThemeModeDb>().withDefault(const Constant('system'))();
  BoolColumn get hideAmounts => boolean().withDefault(const Constant(false))();

  // Environment settings
  TextColumn get environmentMode =>
      textEnum<EnvironmentModeDb>().withDefault(const Constant('production'))();
  BoolColumn get superuserModeEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get featureLevel =>
      textEnum<FeatureLevelDb>().withDefault(const Constant('stable'))();
}
