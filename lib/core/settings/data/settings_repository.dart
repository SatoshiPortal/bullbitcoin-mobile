import 'dart:async';

import 'package:bb_mobile/core/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_model.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart'
    as domain;
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

class SettingsRepository implements domain.SettingsRepository {
  final SettingsDatasource _settingsDatasource;
  final StreamController<String> _currencyChangeController;

  SettingsRepository({required SettingsDatasource settingsDatasource})
    : _settingsDatasource = settingsDatasource,
      _currencyChangeController = StreamController<String>.broadcast();

  @override
  Stream<String> get currencyChangeStream => _currencyChangeController.stream;

  @override
  Future<void> close() async {
    await _currencyChangeController.close();
  }

  @override
  Future<void> store({
    required int id,
    required Environment environment,
    required BitcoinUnit bitcoinUnit,
    required String currency,
    required Language language,
    required bool hideAmounts,
    required bool isSuperuser,
    required bool isDevModeEnabled,
    required bool useTorProxy,
    required int torProxyPort,
    AppThemeMode themeMode = AppThemeMode.system,
    required bool hideExchangeFeatures,
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
        isDevModeEnabled: isDevModeEnabled,
        useTorProxy: useTorProxy,
        torProxyPort: torProxyPort,
        themeMode: themeMode,
        hideExchangeFeatures: hideExchangeFeatures,
      ),
    );
  }

  @override
  Future<SettingsEntity> fetch() async {
    final s = await _settingsDatasource.fetch();

    return SettingsEntity(
      environment: s.environment,
      bitcoinUnit: s.bitcoinUnit,
      currencyCode: s.currency,
      language: s.language,
      hideAmounts: s.hideAmounts,
      isSuperuser: s.isSuperuser,
      isDevModeEnabled: s.isDevModeEnabled,
      useTorProxy: s.useTorProxy,
      torProxyPort: s.torProxyPort,
      themeMode: s.themeMode,
      hideExchangeFeatures: s.hideExchangeFeatures,
    );
  }

  @override
  Future<void> setEnvironment(Environment env) async {
    await _settingsDatasource.setEnvironment(env);
  }

  @override
  Future<void> setBitcoinUnit(BitcoinUnit bitcoinUnit) async {
    await _settingsDatasource.setBitcoinUnit(bitcoinUnit);
  }

  @override
  Future<void> setLanguage(Language language) async {
    await _settingsDatasource.setLanguage(language);
  }

  @override
  Future<void> setCurrency(String currencyCode) async {
    await _settingsDatasource.setCurrency(currencyCode);
    _currencyChangeController.add(currencyCode);
  }

  @override
  Future<void> setHideAmounts(bool hide) async {
    await _settingsDatasource.setHideAmounts(hide);
  }

  @override
  Future<void> setIsSuperuser(bool superuser) async {
    await _settingsDatasource.setIsSuperuser(superuser);
  }

  @override
  Future<void> setIsDevMode(bool isEnabled) async {
    await _settingsDatasource.setIsDevMode(isEnabled);
  }

  @override
  Future<void> setUseTorProxy(bool useTorProxy) async {
    await _settingsDatasource.setUseTorProxy(useTorProxy);
  }

  @override
  Future<void> setTorProxyPort(int port) async {
    await _settingsDatasource.setTorProxyPort(port);
  }

  @override
  Future<void> setThemeMode(AppThemeMode themeMode) async {
    await _settingsDatasource.setThemeMode(themeMode);
  }

  @override
  Future<void> setHideExchangeFeatures(bool hide) async {
    await _settingsDatasource.setHideExchangeFeatures(hide);
  }
}
