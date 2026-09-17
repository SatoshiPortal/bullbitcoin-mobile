import 'dart:async';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_store_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';
import 'package:bull_tor/tor.dart';

/// Reads still throw (`fetch` has ~79 call sites app-wide); the write side is
/// the sanitized boundary: implementations catch, log the raw reason and
/// return a [SettingsStoreFailure].
abstract interface class SettingsRepository {
  Stream<String> get currencyChangeStream;

  @useResult
  Future<Result<void, SettingsStoreFailure>> close();

  @useResult
  Future<Result<void, SettingsStoreFailure>> store({
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

  @useResult
  Future<Result<void, SettingsStoreFailure>> setEnvironment(Environment env);

  @useResult
  Future<Result<void, SettingsStoreFailure>> setBitcoinUnit(
    BitcoinUnit bitcoinUnit,
  );

  @useResult
  Future<Result<void, SettingsStoreFailure>> setLanguage(Language language);

  @useResult
  Future<Result<void, SettingsStoreFailure>> setCurrency(String currencyCode);

  @useResult
  Future<Result<void, SettingsStoreFailure>> setHideAmounts(bool hide);

  @useResult
  Future<Result<void, SettingsStoreFailure>> setIsSuperuser(bool superuser);

  @useResult
  Future<Result<void, SettingsStoreFailure>> setIsDevMode(bool isEnabled);

  @useResult
  Future<Result<void, SettingsStoreFailure>> setTorProxy({
    required bool enabled,
    required int port,
  });

  @useResult
  Future<Result<void, SettingsStoreFailure>> setTorTransportMode(
    TorTransportMode mode,
  );

  @useResult
  Future<Result<void, SettingsStoreFailure>> setLastSuccessfulTorTransport(
    TorTransport transport,
  );

  @useResult
  Future<Result<void, SettingsStoreFailure>> setThemeMode(
    AppThemeMode themeMode,
  );

  @useResult
  Future<Result<void, SettingsStoreFailure>> setErrorReportingEnabled(
    bool enabled,
  );

  @useResult
  Future<Result<void, SettingsStoreFailure>> setScreenCaptureProtectionEnabled(
    bool enabled,
  );

  @useResult
  Future<Result<void, SettingsStoreFailure>> setExchangeTestnetBasicAuth({
    String? username,
    String? password,
  });
}
