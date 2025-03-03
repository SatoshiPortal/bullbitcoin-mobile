import 'dart:async';

import 'package:bb_mobile/_core/data/datasources/key_value_stores/key_value_storage_data_source.dart';
import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_utils/constants.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final KeyValueStorageDataSource<String> _storage;

  SettingsRepositoryImpl({
    required KeyValueStorageDataSource<String> storage,
  }) : _storage = storage;

  @override
  Future<void> setEnvironment(Environment environment) async {
    await _storage.saveValue(
      key: SettingsConstants.environmentKey,
      value: environment.name,
    );
  }

  @override
  Future<Environment> getEnvironment() async {
    final value = await _storage.getValue(SettingsConstants.environmentKey);
    final environment = Environment.fromName(value ?? Environment.mainnet.name);
    return environment;
  }

  @override
  Future<void> setBitcoinUnit(BitcoinUnit bitcoinUnit) {
    return _storage.saveValue(
      key: SettingsConstants.bitcoinUnitKey,
      value: bitcoinUnit.name,
    );
  }

  @override
  Future<BitcoinUnit> getBitcoinUnit() async {
    final value = await _storage.getValue(SettingsConstants.bitcoinUnitKey);
    final bitcoinUnit = BitcoinUnit.fromName(value ?? BitcoinUnit.btc.name);
    return bitcoinUnit;
  }

  @override
  Future<void> setLanguage(Language language) async {
    return _storage.saveValue(
      key: SettingsConstants.languageKey,
      value: language.name,
    );
  }

  @override
  Future<Language?> getLanguage() async {
    final languageName = await _storage.getValue(SettingsConstants.languageKey);
    if (languageName == null) {
      return null;
    }
    final language = Language.fromName(languageName);
    return language;
  }

  @override
  Future<void> setCurrency(String currencyCode) async {
    return _storage.saveValue(
      key: SettingsConstants.currencyKey,
      value: currencyCode,
    );
  }

  @override
  Future<String> getCurrency() async {
    final currency = await _storage.getValue(SettingsConstants.currencyKey) ??
        SettingsConstants.defaultCurrencyCode;
    return currency;
  }
}
