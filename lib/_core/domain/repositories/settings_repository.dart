import 'package:bb_mobile/_core/domain/entities/settings.dart';

abstract class SettingsRepository {
  Future<void> setEnvironment(Environment environment);
  Future<Environment> getEnvironment();
  Future<void> setBitcoinUnit(BitcoinUnit bitcoinUnit);
  Future<BitcoinUnit> getBitcoinUnit();
  Future<void> setLanguage(Language language);
  Future<Language?> getLanguage();
  Future<void> setCurrency(String currencyCode);
  Future<String> getCurrency();
}
