import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

class SettingsModel {
  final int id;
  final Environment environment;
  final BitcoinUnit bitcoinUnit;
  final Language language;
  final String currency;
  final bool hideAmounts;
  final bool isSuperuser;
  final AppThemeMode themeMode;

  const SettingsModel({
    required this.id,
    required this.environment,
    required this.bitcoinUnit,
    required this.language,
    required this.currency,
    required this.hideAmounts,
    required this.isSuperuser,
    required this.themeMode,
  });
}
