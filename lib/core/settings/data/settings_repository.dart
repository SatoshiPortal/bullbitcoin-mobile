import 'dart:async';

import 'package:bb_mobile/core/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_model.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

class SettingsRepository {
  final SettingsDatasource _settingsDatasource;
  final StreamController<String> _currencyChangeController;

  SettingsRepository({required SettingsDatasource settingsDatasource})
    : _settingsDatasource = settingsDatasource,
      _currencyChangeController = StreamController<String>.broadcast();

  Stream<String> get currencyChangeStream => _currencyChangeController.stream;

  Future<void> close() async {
    await _currencyChangeController.close();
  }

  Future<void> store({
    required int id,
    required Environment environment,
    required BitcoinUnit bitcoinUnit,
    required String currency,
    required Language language,
    required bool hideAmounts,
    required bool isSuperuser,
    AppThemeMode themeMode = AppThemeMode.system,
  }) async {
    await _settingsDatasource.store(
      SettingsModel(
        id: id,
        environment: environment,
        bitcoinUnit: bitcoinUnit,
        language: language,
        currency: currency,
        hideAmounts: hideAmounts,
        isSuperuser: isSuperuser,
        themeMode: themeMode,
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
      isSuperuser: s.isSuperuser,
      themeMode: s.themeMode,
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
    _currencyChangeController.add(currencyCode);
  }

  Future<void> setHideAmounts(bool hide) async {
    await _settingsDatasource.setHideAmounts(hide);
  }

  Future<void> setIsSuperuser(bool superuser) async {
    await _settingsDatasource.setIsSuperuser(superuser);
  }

  Future<void> setThemeMode(AppThemeMode themeMode) async {
    await _settingsDatasource.setThemeMode(themeMode);
  }
}
