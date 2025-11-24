import 'dart:async';


import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

abstract class SettingsRepository {
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
}
