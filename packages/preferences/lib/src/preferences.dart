import 'package:preferences/src/data/settings_mapper.dart';

import 'dart:async';

import 'domain/amount_display_preferences.dart';

import 'package:drift/drift.dart' show GeneratedDatabase;
import 'package:meta/meta.dart';

import 'package:preferences/preferences_dao.dart';
import 'package:preferences/src/data/settings_model.dart';
import 'package:preferences/src/domain/settings_repository.dart' as domain;
import 'package:preferences/src/domain/settings_entity.dart';
import 'package:preferences/src/domain/preferences_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_reporting/bull_reporting.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart';

part 'data/legacy_preferences.dart';

/// Application preferences over the caller-owned legacy database.
/// Opening does not perform I/O or migrate the database.
class Preferences implements domain.SettingsRepository {
  final PreferencesDao _settingsDatasource;
  final StreamController<Result<String, PreferencesFailure>>
  _currencyChangeController;
  final StreamController<Result<Environment, PreferencesFailure>>
  _environmentChangeController;

  late final AnnouncementDismissals announcementDismissals =
      AnnouncementDismissals._(_settingsDatasource);
  late final RecoverBullPreferences recoverBull = RecoverBullPreferences._(
    _settingsDatasource,
  );

  Preferences._({required this._settingsDatasource})
    : _currencyChangeController =
          StreamController<Result<String, PreferencesFailure>>.broadcast(),
      _environmentChangeController =
          StreamController<Result<Environment, PreferencesFailure>>.broadcast();

  factory Preferences.open({required GeneratedDatabase database}) =>
      Preferences._(settingsDatasource: PreferencesDao(database));

  @override
  Stream<Result<String, PreferencesFailure>> get currencyChangeStream =>
      _currencyChangeController.stream;

  @override
  Stream<Result<Environment, PreferencesFailure>> get environmentChangeStream =>
      _environmentChangeController.stream;

  @override
  Future<void> close() async {
    await _currencyChangeController.close();
    await _environmentChangeController.close();
  }

  @override
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
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: store',
        error: e.runtimeType,
        trace: st,
      );
      return Err(PreferencesWriteFailure('store failed: ${e.runtimeType}'));
    }
  }

  @override
  Stream<Result<AmountDisplayPreferences, PreferencesFailure>>
  watchDisplayPreferences() => _settingsDatasource
      .watchSettings()
      .map<Result<AmountDisplayPreferences, PreferencesFailure>>((row) {
        if (row == null) return const Err(PreferencesMissingFailure());
        final unit = BitcoinUnit.values.asNameMap()[row.bitcoinUnit];
        if (unit == null) return const Err(PreferencesInvalidFailure());
        return Ok((
          bitcoinUnit: unit,
          hideAmounts: row.hideAmounts,
          currencyCode: row.currency,
        ));
      })
      .transform(
        StreamTransformer<
          Result<AmountDisplayPreferences, PreferencesFailure>,
          Result<AmountDisplayPreferences, PreferencesFailure>
        >.fromHandlers(
          handleError: (error, trace, sink) {
            if (error is Exception) {
              sink.add(
                Err(PreferencesReadFailure(error.runtimeType.toString())),
              );
            } else {
              sink.addError(error, trace);
            }
          },
        ),
      )
      .distinct(
        (a, b) =>
            a.fold<Object>(
              (value) => value,
              (failure) => failure.runtimeType,
            ) ==
            b.fold<Object>((value) => value, (failure) => failure.runtimeType),
      );

  @override
  @useResult
  Future<Result<Language?, PreferencesFailure>> readLanguage() async =>
      (await fetch()).map((settings) => settings.language);

  @override
  @useResult
  Future<Result<String, PreferencesFailure>> readCurrency() async =>
      (await fetch()).map((settings) => settings.currencyCode);

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setStartAmountsInFiat(
    bool fiat,
  ) async {
    try {
      await _settingsDatasource.setStartAmountsInFiat(fiat);
      return const Ok(null);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (error, trace) {
      log.severe(
        message: 'Failed to persist amount input preference',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(
        PreferencesWriteFailure(
          'setStartAmountsInFiat failed: ${error.runtimeType}',
        ),
      );
    }
  }

  @override
  @useResult
  Future<Result<Environment, PreferencesFailure>>
  readActiveEnvironment() async =>
      (await fetch()).map((settings) => settings.environment);

  @override
  @useResult
  Future<Result<domain.ConnectionPreferences, PreferencesFailure>>
  readConnectionPreferences() async => (await fetch()).map(
    (settings) => (
      isSuperuser: settings.isSuperuser,
      isDevModeEnabled: settings.isDevModeEnabled,
      useTorProxy: settings.useTorProxy,
      torProxyPort: settings.torProxyPort,
    ),
  );

  @override
  @useResult
  Future<Result<domain.DeveloperEnvironmentPreferences, PreferencesFailure>>
  readDeveloperEnvironment() async => (await fetch()).map(
    (settings) => (
      environment: settings.environment,
      isSuperuser: settings.isSuperuser,
      isDevModeEnabled: settings.isDevModeEnabled,
    ),
  );

  @override
  @useResult
  Future<Result<domain.TorProxyPreferences, PreferencesFailure>>
  readTorProxyPreferences() async => (await fetch()).map(
    (settings) => (
      useTorProxy: settings.useTorProxy,
      torProxyPort: settings.torProxyPort,
    ),
  );

  @override
  @useResult
  Future<Result<domain.ExchangeWebPreferences, PreferencesFailure>>
  readExchangeWebPreferences() async => (await fetch()).map(
    (settings) => (
      environment: settings.environment,
      exchangeTestnetBasicAuthUsername:
          settings.environment == Environment.testnet
          ? settings.exchangeTestnetBasicAuthUsername
          : null,
      exchangeTestnetBasicAuthPassword:
          settings.environment == Environment.testnet
          ? settings.exchangeTestnetBasicAuthPassword
          : null,
    ),
  );

  @override
  @useResult
  Future<Result<SettingsEntity, PreferencesFailure>> fetch() async {
    try {
      return Ok(settingsEntityFromModel(await _settingsDatasource.fetch()));
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on FormatException {
      return const Err(PreferencesInvalidFailure());
    } on Exception catch (error) {
      return Err(PreferencesReadFailure(error.runtimeType.toString()));
    }
  }

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setEnvironment(
    Environment env,
  ) async {
    try {
      await _settingsDatasource.setEnvironment(env);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setEnvironment',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        PreferencesWriteFailure('setEnvironment failed: ${e.runtimeType}'),
      );
    }
    if (!_environmentChangeController.isClosed) {
      _environmentChangeController.add(Ok(env));
    }
    return const Ok(null);
  }

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setBitcoinUnit(
    BitcoinUnit bitcoinUnit,
  ) async {
    try {
      await _settingsDatasource.setBitcoinUnit(bitcoinUnit);
      return const Ok(null);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setBitcoinUnit',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        PreferencesWriteFailure('setBitcoinUnit failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setLanguage(
    Language language,
  ) async {
    try {
      await _settingsDatasource.setLanguage(language);
      return const Ok(null);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setLanguage',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        PreferencesWriteFailure('setLanguage failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setCurrency(
    String currencyCode,
  ) async {
    try {
      await _settingsDatasource.setCurrency(currencyCode);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setCurrency',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        PreferencesWriteFailure('setCurrency failed: ${e.runtimeType}'),
      );
    }

    // Announced only after the write succeeded, and outside the try: a closed
    // controller (a late write after `close`) would otherwise report a
    // persisted change as a storage failure.
    if (!_currencyChangeController.isClosed) {
      _currencyChangeController.add(Ok(currencyCode));
    }

    return const Ok(null);
  }

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setHideAmounts(bool hide) async {
    try {
      await _settingsDatasource.setHideAmounts(hide);
      return const Ok(null);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setHideAmounts',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        PreferencesWriteFailure('setHideAmounts failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setIsSuperuser(
    bool superuser,
  ) async {
    try {
      await _settingsDatasource.setIsSuperuser(superuser);
      return const Ok(null);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setIsSuperuser',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        PreferencesWriteFailure('setIsSuperuser failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setIsDevMode(bool isEnabled) async {
    try {
      await _settingsDatasource.setIsDevMode(isEnabled);
      return const Ok(null);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setIsDevMode',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        PreferencesWriteFailure('setIsDevMode failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setTorProxy({
    required bool enabled,
    required int port,
  }) async {
    try {
      await _settingsDatasource.setTorProxy(enabled: enabled, port: port);
      return const Ok(null);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setTorProxy',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        PreferencesWriteFailure('setTorProxy failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setTorTransportMode(
    TorTransportMode mode,
  ) async {
    try {
      await _settingsDatasource.setTorTransportMode(mode);
      return const Ok(null);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setTorTransportMode',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        PreferencesWriteFailure('setTorTransportMode failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setLastSuccessfulTorTransport(
    TorTransport transport,
  ) async {
    try {
      await _settingsDatasource.setLastSuccessfulTorTransport(transport);
      return const Ok(null);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setLastSuccessfulTorTransport',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        PreferencesWriteFailure(
          'setLastSuccessfulTorTransport failed: ${e.runtimeType}',
        ),
      );
    }
  }

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setThemeMode(
    AppThemeMode themeMode,
  ) async {
    try {
      await _settingsDatasource.setThemeMode(themeMode);
      return const Ok(null);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setThemeMode',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        PreferencesWriteFailure('setThemeMode failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setExchangeTestnetBasicAuth({
    String? username,
    String? password,
  }) async {
    try {
      await _settingsDatasource.setExchangeTestnetBasicAuth(
        username: username,
        password: password,
      );
      return const Ok(null);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setExchangeTestnetBasicAuth',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        PreferencesWriteFailure(
          'setExchangeTestnetBasicAuth failed: ${e.runtimeType}',
        ),
      );
    }
  }

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setErrorReportingEnabled(
    bool enabled,
  ) async {
    try {
      await _settingsDatasource.setErrorReportingEnabled(enabled);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setErrorReportingEnabled',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        PreferencesWriteFailure(
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
    } on Exception catch (e, st) {
      log.severe(
        message: 'Error-reporting consent saved but the boot mirror is stale',
        error: e.runtimeType,
        trace: st,
      );
    }

    return const Ok(null);
  }

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setScreenCaptureProtectionEnabled(
    bool enabled,
  ) async {
    try {
      await _settingsDatasource.setScreenCaptureProtectionEnabled(enabled);
      return const Ok(null);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message:
            'Failed to persist settings: setScreenCaptureProtectionEnabled',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        PreferencesWriteFailure(
          'setScreenCaptureProtectionEnabled failed: ${e.runtimeType}',
        ),
      );
    }
  }
}

/// Test-only injection of the owned persistence boundary.
extension PreferencesTesting on Preferences {
  static Preferences fromDao(PreferencesDao dao) =>
      Preferences._(settingsDatasource: dao);
}
