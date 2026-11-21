import 'dart:async';

import 'amount_display_preferences.dart';

import 'package:preferences/src/domain/settings_entity.dart';
import 'package:preferences/src/domain/preferences_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import 'package:bull_tor/tor.dart';

abstract interface class ActiveEnvironmentReader {
  @useResult
  Future<Result<Environment, PreferencesFailure>> readActiveEnvironment();
}

typedef ConnectionPreferences = ({
  bool? isSuperuser,
  bool? isDevModeEnabled,
  bool useTorProxy,
  int torProxyPort,
});

abstract interface class ConnectionPreferencesReader
    implements ActiveEnvironmentReader {
  @useResult
  Future<Result<ConnectionPreferences, PreferencesFailure>>
  readConnectionPreferences();
}

typedef DeveloperEnvironmentPreferences = ({
  Environment environment,
  bool? isSuperuser,
  bool? isDevModeEnabled,
});

abstract interface class DeveloperEnvironmentReader {
  @useResult
  Future<Result<DeveloperEnvironmentPreferences, PreferencesFailure>>
  readDeveloperEnvironment();
}

typedef TorProxyPreferences = ({bool useTorProxy, int torProxyPort});

abstract interface class TorProxyPreferencesReader {
  @useResult
  Future<Result<TorProxyPreferences, PreferencesFailure>>
  readTorProxyPreferences();
}

typedef ExchangeWebPreferences = ({
  Environment environment,
  String? exchangeTestnetBasicAuthUsername,
  String? exchangeTestnetBasicAuthPassword,
});

abstract interface class ExchangeTestnetBasicAuthPreferences {
  @useResult
  Future<Result<ExchangeWebPreferences, PreferencesFailure>>
  readExchangeWebPreferences();

  @useResult
  Future<Result<void, PreferencesFailure>> setExchangeTestnetBasicAuth({
    String? username,
    String? password,
  });
}

abstract interface class RuntimeDisplayPreferencesReader {
  @useResult
  Future<Result<Language?, PreferencesFailure>> readLanguage();
  @useResult
  Future<Result<String, PreferencesFailure>> readCurrency();
  Stream<Result<String, PreferencesFailure>> get currencyChangeStream;
}

abstract interface class AmountInputPreferences {
  @useResult
  Future<Result<void, PreferencesFailure>> setStartAmountsInFiat(bool fiat);
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
  Stream<Result<Environment, PreferencesFailure>> get environmentChangeStream;

  /// Closes the change streams. Not a persistence write, so it does not
  /// return a write failure.
  Future<void> close();

  @useResult
  Future<Result<void, PreferencesFailure>> store({
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

  @useResult
  Future<Result<SettingsEntity, PreferencesFailure>> fetch();

  @useResult
  Future<Result<void, PreferencesFailure>> setEnvironment(Environment env);

  @useResult
  Future<Result<void, PreferencesFailure>> setBitcoinUnit(
    BitcoinUnit bitcoinUnit,
  );

  @useResult
  Future<Result<void, PreferencesFailure>> setLanguage(Language language);

  @useResult
  Future<Result<void, PreferencesFailure>> setCurrency(String currencyCode);

  @useResult
  Future<Result<void, PreferencesFailure>> setHideAmounts(bool hide);

  @useResult
  Future<Result<void, PreferencesFailure>> setIsSuperuser(bool superuser);

  @useResult
  Future<Result<void, PreferencesFailure>> setIsDevMode(bool isEnabled);

  @useResult
  Future<Result<void, PreferencesFailure>> setTorProxy({
    required bool enabled,
    required int port,
  });

  @useResult
  Future<Result<void, PreferencesFailure>> setTorTransportMode(
    TorTransportMode mode,
  );

  @useResult
  Future<Result<void, PreferencesFailure>> setLastSuccessfulTorTransport(
    TorTransport transport,
  );

  @useResult
  Future<Result<void, PreferencesFailure>> setThemeMode(AppThemeMode themeMode);

  @useResult
  Future<Result<void, PreferencesFailure>> setErrorReportingEnabled(
    bool enabled,
  );

  @useResult
  Future<Result<void, PreferencesFailure>> setScreenCaptureProtectionEnabled(
    bool enabled,
  );
}
