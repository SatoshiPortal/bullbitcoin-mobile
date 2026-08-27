import 'dart:async';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bull_tor/tor.dart';

abstract interface class SettingsRepository {
  Stream<String> get currencyChangeStream;

  Future<void> close();

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
    bool screenCaptureProtectionEnabled = true,
    String? exchangeTestnetBasicAuthUsername,
    String? exchangeTestnetBasicAuthPassword,
  });

  Future<SettingsEntity> fetch();

  Future<void> setEnvironment(Environment env);

  Future<void> setBitcoinUnit(BitcoinUnit bitcoinUnit);

  Future<void> setLanguage(Language language);

  Future<void> setCurrency(String currencyCode);

  Future<void> setHideAmounts(bool hide);

  Future<void> setIsSuperuser(bool superuser);

  Future<void> setIsDevMode(bool isEnabled);

  Future<void> setTorProxy({required bool enabled, required int port});

  Future<void> setTorTransportMode(TorTransportMode mode);

  Future<void> setLastSuccessfulTorTransport(TorTransport transport);

  Future<void> setThemeMode(AppThemeMode themeMode);

  Future<void> setErrorReportingEnabled(bool enabled);

  Future<void> setScreenCaptureProtectionEnabled(bool enabled);

  Future<void> setExchangeTestnetBasicAuth({
    String? username,
    String? password,
  });
}
