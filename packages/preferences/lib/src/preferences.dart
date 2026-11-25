import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_reporting/bull_reporting.dart';
import 'package:bull_tor/tor.dart';
import 'package:drift/drift.dart' show GeneratedDatabase;
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart'
    show
        DatabaseKeys,
        DatabaseKeyProblem,
        DatabaseKeyUnavailable,
        DatabaseNotReady,
        DatabaseOpenFailure;

import 'data/legacy_preferences_dao.dart';
import 'data/preferences_dao.dart';
import 'data/preferences_import.dart';
import 'data/preferences_store.dart';
import 'data/settings_mapper.dart';
import 'domain/amount_display_preferences.dart';
import 'domain/preferences_failure.dart';
import 'domain/settings_entity.dart';
import 'domain/settings_repository.dart' as domain;

part 'data/legacy_preferences.dart';

/// Encrypted preferences with borrowed legacy access for unmigrated owners.
/// Opening requires runtime admission and committed owner readiness.
class Preferences implements domain.SettingsRepository {
  /// Applies the primary store's consent once foreground startup admits it.
  Future<void> refreshReportingConsent() => Report.refreshConsent(
    () async => (await fetch()).fold(
      (value) => value.isErrorReportingEnabled,
      (_) => throw Exception('Preferences read failed'),
    ),
  );

  final PreferencesDao _settingsDatasource;
  final PreferencesStore? _store;
  final LegacyPreferencesDao Function() _legacyFactory;
  late final LegacyPreferencesDao _legacy = _legacyFactory();
  final StreamController<Result<String, PreferencesFailure>>
  _currencyChangeController;
  final StreamController<Result<Environment, PreferencesFailure>>
  _environmentChangeController;

  late final RecoverBullPreferences recoverBull = RecoverBullPreferences._(
    _settingsDatasource,
  );

  Preferences._({
    required this._settingsDatasource,
    required LegacyPreferencesDao Function() legacy,
    this._store,
  }) : _legacyFactory = legacy,
       _currencyChangeController =
           StreamController<Result<String, PreferencesFailure>>.broadcast(),
       _environmentChangeController =
           StreamController<
             Result<Environment, PreferencesFailure>
           >.broadcast();

  @useResult
  static Future<Result<Preferences, PreferencesFailure>> open({
    required File file,
    required RuntimeAdmission admission,
    required GeneratedDatabase legacyDatabase,
  }) => _open(file: file, admission: admission, legacyDatabase: legacyDatabase);

  static Future<Result<Preferences, PreferencesFailure>> _open({
    required File file,
    required RuntimeAdmission admission,
    required GeneratedDatabase legacyDatabase,
    DatabaseKeys? testingKeys,
  }) async {
    final opened = await PreferencesStore.open(
      file,
      admission,
      existing: true,
      testingKeys: testingKeys,
    );
    if (opened case Err(:final failure)) {
      return Err(
        PreferencesStorageFailure(
          deferred:
              failure is DatabaseNotReady ||
              failure is DatabaseKeyUnavailable &&
                  failure.reason == DatabaseKeyProblem.locked,
        ),
      );
    }
    final store = (opened as Ok<PreferencesStore, DatabaseOpenFailure>).value;
    final readiness = await readPreferencesReadiness(store.database);
    if (readiness case Ok(value: final ready)
        when ready != OwnerReadiness.pending) {
      return Ok(
        Preferences._(
          settingsDatasource: PreferencesDao(store.database),
          legacy: () => LegacyPreferencesDao(legacyDatabase),
          store: store,
        ),
      );
    }
    try {
      await store.handle.close();
    } on Exception {
      // The admission still owns the unconfirmed native handle.
      return const Err(PreferencesStorageFailure());
    }
    return Err(
      PreferencesStorageFailure(
        deferred:
            readiness is Ok<OwnerReadiness, LegacyImportFailure> &&
            readiness.value == OwnerReadiness.pending,
      ),
    );
  }

  @override
  Stream<Result<String, PreferencesFailure>> get currencyChangeStream =>
      _currencyChangeController.stream;

  @override
  Stream<Result<Environment, PreferencesFailure>> get environmentChangeStream =>
      _environmentChangeController.stream;

  @override
  Future<void> close() async {
    // Paused broadcast listeners can defer stream completion, but must never
    // keep the tracked database or its background admission alive.
    unawaited(_currencyChangeController.close());
    unawaited(_environmentChangeController.close());
    await _store?.handle.close();
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
      (await _fetchOwner()).map((settings) => settings.language);

  @override
  @useResult
  Future<Result<String, PreferencesFailure>> readCurrency() async =>
      (await _fetchOwner()).map((settings) => settings.currencyCode);

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
      (await _fetchOwner()).map((settings) => settings.environment);

  @override
  @useResult
  Future<Result<domain.ConnectionPreferences, PreferencesFailure>>
  readConnectionPreferences() async => (await _fetchOwner()).map(
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
  readDeveloperEnvironment() async => (await _fetchOwner()).map(
    (settings) => (
      environment: settings.environment,
      isSuperuser: settings.isSuperuser,
      isDevModeEnabled: settings.isDevModeEnabled,
    ),
  );

  @override
  @useResult
  Future<Result<domain.TorProxyPreferences, PreferencesFailure>>
  readTorProxyPreferences() async => (await _fetchOwner()).map(
    (settings) => (
      useTorProxy: settings.useTorProxy,
      torProxyPort: settings.torProxyPort,
    ),
  );

  @override
  @useResult
  Future<Result<bool, PreferencesFailure>> readShowPaymentAnimations() async =>
      (await _fetchOwner()).map((settings) => settings.showPaymentAnimations);

  @override
  @useResult
  Future<Result<domain.ExchangeWebPreferences, PreferencesFailure>>
  readExchangeWebPreferences() async =>
      (await _fetchWithLegacyCredentials()).map(
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
  Future<Result<SettingsEntity, PreferencesFailure>> fetch() => _fetchOwner();

  /// Composes the owner settings with credentials still needed by the legacy UI.
  @useResult
  Future<Result<SettingsEntity, PreferencesFailure>> fetchForSettingsScreen() =>
      _fetchWithLegacyCredentials();

  Future<Result<SettingsEntity, PreferencesFailure>>
  _fetchWithLegacyCredentials() async {
    final owned = await _fetchOwner();
    if (owned case Err()) return owned;
    try {
      final credentials = await _legacy.readCredentials();
      return owned.map(
        (settings) => settings.copyWith(
          exchangeTestnetBasicAuthUsername: credentials.username,
          exchangeTestnetBasicAuthPassword: credentials.password,
        ),
      );
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception {
      return const Err(PreferencesReadFailure());
    }
  }

  Future<Result<SettingsEntity, PreferencesFailure>> _fetchOwner() async {
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
      await _legacy.setExchangeTestnetBasicAuth(
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

  @override
  @useResult
  Future<Result<void, PreferencesFailure>> setShowPaymentAnimations(
    bool enabled,
  ) async {
    try {
      await _settingsDatasource.setShowPaymentAnimations(enabled);
      return const Ok(null);
    } on PreferencesMissingRowException {
      return const Err(PreferencesMissingFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: setShowPaymentAnimations',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        PreferencesWriteFailure(
          'setShowPaymentAnimations failed: ${e.runtimeType}',
        ),
      );
    }
  }
}

/// Test-only injection of the owned persistence boundary.
extension PreferencesTesting on Preferences {
  static Future<Result<Preferences, PreferencesFailure>> open({
    required File file,
    required RuntimeAdmission admission,
    required GeneratedDatabase legacyDatabase,
    required DatabaseKeys keys,
  }) => Preferences._open(
    file: file,
    admission: admission,
    legacyDatabase: legacyDatabase,
    testingKeys: keys,
  );

  static Preferences fromDao(
    PreferencesDao dao, {
    LegacyPreferencesDao? legacy,
  }) => Preferences._(
    settingsDatasource: dao,
    legacy: () => legacy ?? LegacyPreferencesDao(dao.attachedDatabase),
  );

  static Preferences fromDatabases({
    required GeneratedDatabase owner,
    required GeneratedDatabase legacy,
  }) => Preferences._(
    settingsDatasource: PreferencesDao(owner),
    legacy: () => LegacyPreferencesDao(legacy),
  );
}
