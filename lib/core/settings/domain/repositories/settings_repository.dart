import 'dart:async';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';

abstract class SettingsRepository {
  Stream<String> get currencyChangeStream;

  /// Emits the new value every time [setPayjoinEnabled] persists a change,
  /// so a live listener (the receive flow) can react to the setting being
  /// flipped elsewhere in the app without needing to re-enter its screen.
  Stream<bool> get payjoinEnabledChangeStream;

  /// Emits the new anti-probing threshold after it has been persisted.
  Stream<int> get payjoinMinAmountChangeStream;

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
    AppThemeMode themeMode = AppThemeMode.system,
    bool isErrorReportingEnabled = false,
    String? exchangeTestnetBasicAuthUsername,
    String? exchangeTestnetBasicAuthPassword,
    bool isPayjoinEnabled = false,
    int payjoinMinAmountSat = PayjoinConstants.defaultMinAmountSat,
    int payjoinExpireAfterSec = PayjoinConstants.defaultExpireAfterSec,
  });

  Future<SettingsEntity> fetch();

  Future<void> setEnvironment(Environment env);

  Future<void> setBitcoinUnit(BitcoinUnit bitcoinUnit);

  Future<void> setLanguage(Language language);

  Future<void> setCurrency(String currencyCode);

  Future<void> setHideAmounts(bool hide);

  Future<void> setIsSuperuser(bool superuser);

  Future<void> setIsDevMode(bool isEnabled);

  Future<void> setUseTorProxy(bool useTorProxy);

  Future<void> setTorProxyPort(int port);

  Future<void> setThemeMode(AppThemeMode themeMode);

  Future<void> setErrorReportingEnabled(bool enabled);

  Future<void> setPayjoinEnabled(bool enabled);

  Future<void> setPayjoinMinAmountSat(int amountSat);

  Future<void> setPayjoinExpireAfterSec(int expireAfterSec);

  Future<void> setExchangeTestnetBasicAuth({
    String? username,
    String? password,
  });
}
