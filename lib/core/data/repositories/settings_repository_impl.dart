import 'dart:async';

import 'package:bb_mobile/core/data/datasources/key_value_stores/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  static const _environmentKey = 'environment';
  static const _bitcoinUnitKey = 'bitcoinUnit';
  static const _languageKey = 'language';
  // TODO: add fiat currency key and settings, and remove the fiat_currency feature
  // every feature that needs exchange rate, should fetch the exchange rate itself
  // so no special feature is needed for fiat_currency
  //static const _fiatCurrencyKey = 'fiatCurrency';

  final KeyValueStorageDataSource<String> _storage;

  SettingsRepositoryImpl({
    required KeyValueStorageDataSource<String> storage,
  }) : _storage = storage;

  @override
  Future<void> setEnvironment(Environment environment) async {
    await _storage.saveValue(
      key: _environmentKey,
      value: environment.name,
    );
  }

  @override
  Future<Environment> getEnvironment() async {
    final value = await _storage.getValue(_environmentKey);
    final environment = Environment.fromName(value ?? Environment.mainnet.name);
    return environment;
  }

  @override
  Future<void> setBitcoinUnit(BitcoinUnit bitcoinUnit) {
    return _storage.saveValue(
      key: _bitcoinUnitKey,
      value: bitcoinUnit.name,
    );
  }

  @override
  Future<BitcoinUnit> getBitcoinUnit() async {
    final value = await _storage.getValue(_bitcoinUnitKey);
    final bitcoinUnit = BitcoinUnit.fromName(value ?? BitcoinUnit.btc.name);
    return bitcoinUnit;
  }

  @override
  Future<void> setLanguage(Language language) async {
    return _storage.saveValue(key: _languageKey, value: language.name);
  }

  @override
  Future<Language?> getLanguage() async {
    final languageName = await _storage.getValue(_languageKey);
    if (languageName == null) {
      return null;
    }
    final language = Language.fromName(languageName);
    return language;
  }
}
