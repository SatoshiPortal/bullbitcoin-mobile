import 'dart:async';

import 'package:bb_mobile/core/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_model.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart'
    as domain;
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_store_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/utils/report.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart';

class SettingsRepository implements domain.SettingsRepository {
  final SettingsDatasource _settingsDatasource;
  final StreamController<String> _currencyChangeController;

  SettingsRepository({required this._settingsDatasource})
    : _currencyChangeController = StreamController<String>.broadcast();

  @override
  Stream<String> get currencyChangeStream => _currencyChangeController.stream;

  @override
  Future<Result<void, SettingsStoreFailure>> close() async {
    try {
      await _currencyChangeController.close();
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to persist settings: close',
        error: e.runtimeType,
        trace: st,
      );
      return Err(SettingsStoreWriteFailure('close failed: ${e.runtimeType}'));
    }
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
  Future<SettingsEntity> fetch() async {
    final s = await _settingsDatasource.fetch();

    return SettingsEntity(
      environment: s.environment,
      bitcoinUnit: s.bitcoinUnit,
      currencyCode: s.currency,
      language: s.language,
      hideAmounts: s.hideAmounts,
      isSuperuser: s.isSuperuser,
      isDevModeEnabled: s.isDevModeEnabled,
      useTorProxy: s.useTorProxy,
      torProxyPort: s.torProxyPort,
      torTransportMode: s.torTransportMode,
      lastSuccessfulTorTransport: s.lastSuccessfulTorTransport,
      themeMode: s.themeMode,
      isErrorReportingEnabled: s.isErrorReportingEnabled,
      screenCaptureProtectionEnabled: s.screenCaptureProtectionEnabled,
      exchangeTestnetBasicAuthUsername: s.exchangeTestnetBasicAuthUsername,
      exchangeTestnetBasicAuthPassword: s.exchangeTestnetBasicAuthPassword,
    );
  }

  @override
  Future<Result<void, SettingsStoreFailure>> setEnvironment(
    Environment env,
  ) async {
    try {
      await _settingsDatasource.setEnvironment(env);
      return const Ok(null);
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

    // Only the write above decides Ok/Err. This mirror feeds the next cold
    // start's Sentry init; failing to update it does not un-persist the
    // preference, and reporting it as "not saved" would tell the user their
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
