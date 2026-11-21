import 'package:preferences/src/data/settings_mapper.dart';

import 'dart:async';

import '../domain/amount_display_preferences.dart';

import 'package:preferences/preferences_dao.dart';
import 'package:preferences/src/data/settings_model.dart';
import 'package:preferences/src/domain/settings_repository.dart' as domain;
import 'package:preferences/src/domain/settings_entity.dart';
import 'package:preferences/src/domain/settings_store_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_reporting/bull_reporting.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart';

class SettingsRepositoryImpl implements domain.SettingsRepository {
  final PreferencesDao _settingsDatasource;
  final StreamController<String> _currencyChangeController;
  final StreamController<Environment> _environmentChangeController;

  SettingsRepositoryImpl({required this._settingsDatasource})
    : _currencyChangeController = StreamController<String>.broadcast(),
      _environmentChangeController = StreamController<Environment>.broadcast();

  @override
  Stream<String> get currencyChangeStream => _currencyChangeController.stream;

  @override
  Stream<Environment> get environmentChangeStream =>
      _environmentChangeController.stream;

  @override
  Future<void> close() async {
    await _currencyChangeController.close();
    await _environmentChangeController.close();
  }

  @override
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
  }) async {
    try {
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
          screenCaptureProtectionEnabled: screenCaptureProtectionEnabled,
          exchangeTestnetBasicAuthUsername: exchangeTestnetBasicAuthUsername,
          exchangeTestnetBasicAuthPassword: exchangeTestnetBasicAuthPassword,
        ),
      );
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: store',
        error: e.runtimeType,
        trace: st,
      );
      return Err(SettingsStoreWriteFailure('store failed: ${e.runtimeType}'));
    }
  }

  @override
  Stream<AmountDisplayPreferences?> watchDisplayPreferences() =>
      _settingsDatasource
          .watchSettings()
          .map((row) {
            if (row == null) return null;
            final unit = BitcoinUnit.values.asNameMap()[row.bitcoinUnit];
            if (unit == null) return null;
            return (
              bitcoinUnit: unit,
              hideAmounts: row.hideAmounts,
              currencyCode: row.currency,
            );
          })
          .transform(
            StreamTransformer<
              AmountDisplayPreferences?,
              AmountDisplayPreferences?
            >.fromHandlers(
              handleError: (error, trace, sink) {
                if (error is Exception) {
                  log.warning(
                    'Could not watch display preferences: ${error.runtimeType}',
                    trace: trace,
                  );
                  sink.add(null);
                } else {
                  sink.addError(error, trace);
                }
              },
            ),
          )
          .distinct();

  @override
  Future<Language?> readLanguage() async => (await fetch()).language;

  @override
  Future<String> readCurrency() async => (await fetch()).currencyCode;

  @override
  Future<Result<void, SettingsStoreFailure>> setStartAmountsInFiat(
    bool fiat,
  ) async {
    try {
      await _settingsDatasource.setStartAmountsInFiat(fiat);
      return const Ok(null);
    } on Exception catch (error, trace) {
      log.severe(
        message: 'Failed to persist amount input preference',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(
        SettingsStoreWriteFailure(
          'setStartAmountsInFiat failed: ${error.runtimeType}',
        ),
      );
    }
  }

  @override
  Future<Environment> readActiveEnvironment() async =>
      (await fetch()).environment;

  @override
  Future<domain.ConnectionPreferences> readConnectionPreferences() async {
    final settings = await fetch();
    return (
      isSuperuser: settings.isSuperuser,
      isDevModeEnabled: settings.isDevModeEnabled,
      useTorProxy: settings.useTorProxy,
      torProxyPort: settings.torProxyPort,
    );
  }

  @override
  Future<domain.DeveloperEnvironmentPreferences>
  readDeveloperEnvironment() async {
    final settings = await fetch();
    return (
      environment: settings.environment,
      isSuperuser: settings.isSuperuser,
      isDevModeEnabled: settings.isDevModeEnabled,
    );
  }

  @override
  Future<domain.TorProxyPreferences> readTorProxyPreferences() async {
    final settings = await fetch();
    return (
      useTorProxy: settings.useTorProxy,
      torProxyPort: settings.torProxyPort,
    );
  }

  @override
  Future<domain.ExchangeWebPreferences> readExchangeWebPreferences() async {
    final settings = await fetch();
    final useTestnet = settings.environment == Environment.testnet;
    return (
      environment: settings.environment,
      exchangeTestnetBasicAuthUsername: useTestnet
          ? settings.exchangeTestnetBasicAuthUsername
          : null,
      exchangeTestnetBasicAuthPassword: useTestnet
          ? settings.exchangeTestnetBasicAuthPassword
          : null,
    );
  }

  @override
  Future<SettingsEntity> fetch() async {
    final s = await _settingsDatasource.fetch();

    return settingsEntityFromModel(s);
  }

  @override
  Future<Result<void, SettingsStoreFailure>> setEnvironment(
    Environment env,
  ) async {
    try {
      await _settingsDatasource.setEnvironment(env);
    } catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setEnvironment',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        SettingsStoreWriteFailure('setEnvironment failed: ${e.runtimeType}'),
      );
    }
    if (!_environmentChangeController.isClosed) {
      _environmentChangeController.add(env);
    }
    return const Ok(null);
  }

  @override
  Future<Result<void, SettingsStoreFailure>> setBitcoinUnit(
    BitcoinUnit bitcoinUnit,
  ) async {
    try {
      await _settingsDatasource.setBitcoinUnit(bitcoinUnit);
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setBitcoinUnit',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        SettingsStoreWriteFailure('setBitcoinUnit failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  Future<Result<void, SettingsStoreFailure>> setLanguage(
    Language language,
  ) async {
    try {
      await _settingsDatasource.setLanguage(language);
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setLanguage',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        SettingsStoreWriteFailure('setLanguage failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  Future<Result<void, SettingsStoreFailure>> setCurrency(
    String currencyCode,
  ) async {
    try {
      await _settingsDatasource.setCurrency(currencyCode);
    } catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setCurrency',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        SettingsStoreWriteFailure('setCurrency failed: ${e.runtimeType}'),
      );
    }

    // Announced only after the write succeeded, and outside the try: a closed
    // controller (a late write after `close`) would otherwise report a
    // persisted change as a storage failure.
    if (!_currencyChangeController.isClosed) {
      _currencyChangeController.add(currencyCode);
    }

    return const Ok(null);
  }

  @override
  Future<Result<void, SettingsStoreFailure>> setHideAmounts(bool hide) async {
    try {
      await _settingsDatasource.setHideAmounts(hide);
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setHideAmounts',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        SettingsStoreWriteFailure('setHideAmounts failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  Future<Result<void, SettingsStoreFailure>> setIsSuperuser(
    bool superuser,
  ) async {
    try {
      await _settingsDatasource.setIsSuperuser(superuser);
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setIsSuperuser',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        SettingsStoreWriteFailure('setIsSuperuser failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  Future<Result<void, SettingsStoreFailure>> setIsDevMode(
    bool isEnabled,
  ) async {
    try {
      await _settingsDatasource.setIsDevMode(isEnabled);
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setIsDevMode',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        SettingsStoreWriteFailure('setIsDevMode failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  Future<Result<void, SettingsStoreFailure>> setTorProxy({
    required bool enabled,
    required int port,
  }) async {
    try {
      await _settingsDatasource.setTorProxy(enabled: enabled, port: port);
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setTorProxy',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        SettingsStoreWriteFailure('setTorProxy failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  Future<Result<void, SettingsStoreFailure>> setTorTransportMode(
    TorTransportMode mode,
  ) async {
    try {
      await _settingsDatasource.setTorTransportMode(mode);
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setTorTransportMode',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        SettingsStoreWriteFailure(
          'setTorTransportMode failed: ${e.runtimeType}',
        ),
      );
    }
  }

  @override
  Future<Result<void, SettingsStoreFailure>> setLastSuccessfulTorTransport(
    TorTransport transport,
  ) async {
    try {
      await _settingsDatasource.setLastSuccessfulTorTransport(transport);
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setLastSuccessfulTorTransport',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        SettingsStoreWriteFailure(
          'setLastSuccessfulTorTransport failed: ${e.runtimeType}',
        ),
      );
    }
  }

  @override
  Future<Result<void, SettingsStoreFailure>> setThemeMode(
    AppThemeMode themeMode,
  ) async {
    try {
      await _settingsDatasource.setThemeMode(themeMode);
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setThemeMode',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        SettingsStoreWriteFailure('setThemeMode failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  Future<Result<void, SettingsStoreFailure>> setExchangeTestnetBasicAuth({
    String? username,
    String? password,
  }) async {
    try {
      await _settingsDatasource.setExchangeTestnetBasicAuth(
        username: username,
        password: password,
      );
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setExchangeTestnetBasicAuth',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        SettingsStoreWriteFailure(
          'setExchangeTestnetBasicAuth failed: ${e.runtimeType}',
        ),
      );
    }
  }

  @override
  Future<Result<void, SettingsStoreFailure>> setErrorReportingEnabled(
    bool enabled,
  ) async {
    try {
      await _settingsDatasource.setErrorReportingEnabled(enabled);
    } catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setErrorReportingEnabled',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        SettingsStoreWriteFailure(
          'setErrorReportingEnabled failed: ${e.runtimeType}',
        ),
      );
    }

    // Only the write above decides Ok/Err. updateConsent sets the live
    // Report.consent gate before it writes the boot mirror, so a mirror failure
    // cannot leave reporting on for this session; and boot re-syncs consent
    // from this table (main.dart), so the stale mirror only affects events
    // fired before that. Reporting it as "not saved" would tell the user their
    // choice was lost when it was not.
    try {
      await Report.updateConsent(enabled);
    } catch (e, st) {
      log.severe(
        message: 'Error-reporting consent saved but the boot mirror is stale',
        error: e.runtimeType,
        trace: st,
      );
    }

    return const Ok(null);
  }

  @override
  Future<Result<void, SettingsStoreFailure>> setScreenCaptureProtectionEnabled(
    bool enabled,
  ) async {
    try {
      await _settingsDatasource.setScreenCaptureProtectionEnabled(enabled);
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message:
            'Failed to persist settings: setScreenCaptureProtectionEnabled',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        SettingsStoreWriteFailure(
          'setScreenCaptureProtectionEnabled failed: ${e.runtimeType}',
        ),
      );
    }
  }
}
