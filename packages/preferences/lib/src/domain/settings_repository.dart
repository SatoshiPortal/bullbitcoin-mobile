import 'dart:async';

import 'amount_display_preferences.dart';

import 'package:preferences/src/domain/settings_entity.dart';
import 'package:preferences/src/domain/settings_store_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import 'package:bull_tor/tor.dart';

abstract interface class ActiveEnvironmentReader {
  Future<Environment> readActiveEnvironment();
}

typedef ConnectionPreferences = ({
  bool? isSuperuser,
  bool? isDevModeEnabled,
  bool useTorProxy,
  int torProxyPort,
});

abstract interface class ConnectionPreferencesReader
    implements ActiveEnvironmentReader {
  Future<ConnectionPreferences> readConnectionPreferences();
}

typedef DeveloperEnvironmentPreferences = ({
  Environment environment,
  bool? isSuperuser,
  bool? isDevModeEnabled,
});

abstract interface class DeveloperEnvironmentReader {
  Future<DeveloperEnvironmentPreferences> readDeveloperEnvironment();
}

typedef TorProxyPreferences = ({bool useTorProxy, int torProxyPort});

abstract interface class TorProxyPreferencesReader {
  Future<TorProxyPreferences> readTorProxyPreferences();
}

typedef ExchangeWebPreferences = ({
  Environment environment,
  String? exchangeTestnetBasicAuthUsername,
  String? exchangeTestnetBasicAuthPassword,
});

abstract interface class ExchangeTestnetBasicAuthPreferences {
  Future<ExchangeWebPreferences> readExchangeWebPreferences();

  @useResult
  Future<Result<void, SettingsStoreFailure>> setExchangeTestnetBasicAuth({
    String? username,
    String? password,
  });
}

abstract interface class RuntimeDisplayPreferencesReader {
  Future<Language?> readLanguage();
  Future<String> readCurrency();
  Stream<String> get currencyChangeStream;
}

abstract interface class AmountInputPreferences {
  @useResult
  Future<Result<void, SettingsStoreFailure>> setStartAmountsInFiat(bool fiat);
}

/// The legacy settings aggregate. New consumers can use the narrow readers
/// and writers that this repository implements.
abstract interface class SettingsRepository
    implements
        AmountDisplayPreferencesReader,
        ConnectionPreferencesReader,
        AmountInputPreferences,
        DeveloperEnvironmentReader,
        TorProxyPreferencesReader,
        RuntimeDisplayPreferencesReader,
        ExchangeTestnetBasicAuthPreferences {
  /// The environment after each successful [setEnvironment].
  Stream<Environment> get environmentChangeStream;

  /// Closes the change streams. Not a persistence write, so it does not
  /// return a write failure.
  Future<void> close();

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
}
