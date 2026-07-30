import 'dart:async';

import 'package:bb_mobile/core/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_model.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart'
    as domain;
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/report.dart';
import 'package:tor/tor.dart';

class SettingsRepository implements domain.SettingsRepository {
  final SettingsDatasource _settingsDatasource;
  final StreamController<String> _currencyChangeController;
  final StreamController<bool> _payjoinEnabledChangeController;

  SettingsRepository({required this._settingsDatasource})
    : _currencyChangeController = StreamController<String>.broadcast(),
      _payjoinEnabledChangeController = StreamController<bool>.broadcast();

  @override
  Stream<String> get currencyChangeStream => _currencyChangeController.stream;

  @override
  Stream<bool> get payjoinEnabledChangeStream =>
      _payjoinEnabledChangeController.stream;

  @override
  Future<void> close() async {
    await _currencyChangeController.close();
    await _payjoinEnabledChangeController.close();
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
    TorTransportMode torTransportMode = TorTransportMode.automatic,
    TorTransport? lastSuccessfulTorTransport,
    AppThemeMode themeMode = AppThemeMode.system,
    bool isErrorReportingEnabled = false,
    String? exchangeTestnetBasicAuthUsername,
    String? exchangeTestnetBasicAuthPassword,
    bool isPayjoinEnabled = false,
    int payjoinMinAmountSat = PayjoinConstants.defaultMinAmountSat,
    int payjoinExpireAfterSec = PayjoinConstants.defaultExpireAfterSec,
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
        torTransportMode: torTransportMode,
        lastSuccessfulTorTransport: lastSuccessfulTorTransport,
        themeMode: themeMode,
        isErrorReportingEnabled: isErrorReportingEnabled,
        exchangeTestnetBasicAuthUsername: exchangeTestnetBasicAuthUsername,
        exchangeTestnetBasicAuthPassword: exchangeTestnetBasicAuthPassword,
        payjoinEnabled: isPayjoinEnabled,
        payjoinMinAmountSat: payjoinMinAmountSat,
        payjoinExpireAfterSec: payjoinExpireAfterSec,
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
      torTransportMode: s.torTransportMode,
      lastSuccessfulTorTransport: s.lastSuccessfulTorTransport,
      themeMode: s.themeMode,
      isErrorReportingEnabled: s.isErrorReportingEnabled,
      exchangeTestnetBasicAuthUsername: s.exchangeTestnetBasicAuthUsername,
      exchangeTestnetBasicAuthPassword: s.exchangeTestnetBasicAuthPassword,
      isPayjoinEnabled: s.payjoinEnabled,
      payjoinMinAmountSat: s.payjoinMinAmountSat,
      payjoinExpireAfterSec: s.payjoinExpireAfterSec,
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
  Future<void> setTorTransportMode(TorTransportMode mode) async {
    await _settingsDatasource.setTorTransportMode(mode);
  }

  @override
  Future<void> setLastSuccessfulTorTransport(TorTransport transport) async {
    await _settingsDatasource.setLastSuccessfulTorTransport(transport);
  }

  @override
  Future<void> setThemeMode(AppThemeMode themeMode) async {
    await _settingsDatasource.setThemeMode(themeMode);
  }

  @override
  Future<void> setPayjoinEnabled(bool enabled) async {
    await _settingsDatasource.setPayjoinEnabled(enabled);
    _payjoinEnabledChangeController.add(enabled);
  }

  @override
  Future<void> setPayjoinMinAmountSat(int amountSat) async {
    await _settingsDatasource.setPayjoinMinAmountSat(amountSat);
  }

  @override
  Future<void> setPayjoinExpireAfterSec(int expireAfterSec) async {
    await _settingsDatasource.setPayjoinExpireAfterSec(expireAfterSec);
  }

  @override
  Future<void> setExchangeTestnetBasicAuth({
    String? username,
    String? password,
  }) async {
    await _settingsDatasource.setExchangeTestnetBasicAuth(
      username: username,
      password: password,
    );
  }

  @override
  Future<void> setErrorReportingEnabled(bool enabled) async {
    await _settingsDatasource.setErrorReportingEnabled(enabled);
    // Sync [Report]'s boot-time mirror so the next cold start's Sentry
    // init can seed consent before the locator is available.
    await Report.updateConsent(enabled);
  }
}
