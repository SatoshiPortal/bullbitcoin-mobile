import 'dart:async';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

abstract class SettingsRepository {
  Stream<String> get currencyChangeStream;

  /// Emits every time [setUseTorProxy] is called, with the new value.
  /// `CbfWalletDatasource` subscribes to this (via `WalletLocator`) to
  /// cancel every active compact-filter session the instant the user
  /// enables Tor mid-session — CBF never routes through Tor (V1 has no
  /// `socks5Proxy` support for it), so a session left running would keep
  /// making direct P2P connections against the user's expectation.
  Stream<bool> get torProxyChangeStream;

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
    bool useCompactBlockFiltersByDefault = false,
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

  Future<void> setExchangeTestnetBasicAuth({
    String? username,
    String? password,
  });

  /// Global default sync backend choice for a newly created default
  /// Bitcoin wallet. Read by `CreateDefaultWalletsUsecase`; never touches
  /// an already-existing wallet. Set by the wizard's privacy step, or by
  /// `ApplyPendingWizardChoicesUsecase` only when the user touched it.
  Future<void> setUseCompactBlockFiltersByDefault(bool enabled);
}
