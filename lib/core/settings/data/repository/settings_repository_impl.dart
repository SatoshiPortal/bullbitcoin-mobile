import 'dart:async';

import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final KeyValueStorageDatasource<String> _storage;

  SettingsRepositoryImpl({
    required KeyValueStorageDatasource<String> storage,
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

  @override
  Future<void> setHideAmounts(bool hide) async {
    return _storage.saveValue(
      key: SettingsConstants.hideAmountsKey,
      value: hide.toString(),
    );
  }

  @override
  Future<bool> getHideAmounts() async {
    final hide =
        await _storage.getValue(SettingsConstants.hideAmountsKey) ?? 'false';
    return hide == 'true';
  }
}
