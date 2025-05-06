import 'dart:async';

import 'package:bb_mobile/core/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_model.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

class SettingsRepository {
  final SettingsDatasource _settingsDatasource;

  SettingsRepository({required SettingsDatasource settingsDatasource})
    : _settingsDatasource = settingsDatasource;

  Future<void> store({
    required int id,
    required Environment environment,
    required BitcoinUnit bitcoinUnit,
    required String currency,
    required Language language,
    required bool hideAmounts,
  }) async {
    await _settingsDatasource.store(
      SettingsModel(
        id: id,
        environment: environment,
        bitcoinUnit: bitcoinUnit,
        language: language,
        currency: currency,
        hideAmounts: hideAmounts,
      ),
    );
  }

  Future<SettingsEntity> fetch() async {
    final s = await _settingsDatasource.fetch();

    return SettingsEntity(
      environment: s.environment,
      bitcoinUnit: s.bitcoinUnit,
      currencyCode: s.currency,
      language: s.language,
      hideAmounts: s.hideAmounts,
    );
  }

  Future<void> setEnvironment(Environment env) async {
    await _settingsDatasource.setEnvironment(env);
  }

  Future<void> setBitcoinUnit(BitcoinUnit bitcoinUnit) async {
    await _settingsDatasource.setBitcoinUnit(bitcoinUnit);
  }

  Future<void> setLanguage(Language language) async {
    await _settingsDatasource.setLanguage(language);
  }

  Future<void> setCurrency(String currencyCode) async {
    await _settingsDatasource.setCurrency(currencyCode);
  }

  Future<void> setHideAmounts(bool hide) async {
    await _settingsDatasource.setHideAmounts(hide);
  }
}
