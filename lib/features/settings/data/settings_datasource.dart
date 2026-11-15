import 'package:bb_mobile/features/settings/data/settings_model.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart';

class SettingsDatasource {
  final SqliteDatabase _sqlite;

  SettingsDatasource({required this._sqlite});

  Future<void> store(SettingsModel model) async {
    await _sqlite.into(_sqlite.settings).insert(model.toSqlite());
  }

  /// Repair persisted developer authorization before exposing the active network.
  /// The transaction prevents a concurrent settings write between read and repair.
  Future<SettingsModel> fetch() => _sqlite.transaction(() async {
    var row = await _sqlite.managers.settings
        .filter((f) => f.id(1))
        .getSingle();
    if (row.environment != Environment.mainnet.name &&
        (!row.isSuperuser || !row.isDevModeEnabled)) {
      await setIsDevMode(false);
      row = await _sqlite.managers.settings.filter((f) => f.id(1)).getSingle();
      log.warning('Active network restored category=developerAuthorization');
    }
    return SettingsModel.fromSqlite(row);
  });

  Future<void> setEnvironment(Environment env) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), environment: Value(env.name)),
    );
  }

  Future<void> setBitcoinUnit(BitcoinUnit bitcoinUnit) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), bitcoinUnit: Value(bitcoinUnit.name)),
    );
  }

  Future<void> setLanguage(Language language) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), language: Value(language.name)),
    );
  }

  Future<void> setCurrency(String currencyCode) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), currency: Value(currencyCode)),
    );
  }

  Future<void> setHideAmounts(bool hide) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), hideAmounts: Value(hide)),
    );
  }

  Future<void> setIsSuperuser(bool isSuperuser) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), isSuperuser: Value(isSuperuser)),
    );
  }

  Future<void> setIsDevMode(bool isEnabled) async {
    await _sqlite.managers.settings.update(
      (f) => f(
        id: const Value(1),
        isDevModeEnabled: Value(isEnabled),
        environment: isEnabled
            ? const Value.absent()
            : Value(Environment.mainnet.name),
      ),
    );
  }

  Future<void> setTorProxy({required bool enabled, required int port}) async {
    await _sqlite.managers.settings.update(
      (f) => f(
        id: const Value(1),
        useTorProxy: Value(enabled),
        torProxyPort: Value(port),
      ),
    );
  }

  Future<void> setTorTransportMode(TorTransportMode mode) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), torTransportMode: Value(mode.name)),
    );
  }

  Future<void> setLastSuccessfulTorTransport(TorTransport transport) async {
    await _sqlite.managers.settings.update(
      (f) => f(
        id: const Value(1),
        lastSuccessfulTorTransport: Value(transport.name),
      ),
    );
  }

  Future<void> setThemeMode(AppThemeMode themeMode) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), themeMode: Value(themeMode.name)),
    );
  }

  Future<void> setErrorReportingEnabled(bool enabled) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), isErrorReportingEnabled: Value(enabled)),
    );
  }

  Future<void> setScreenCaptureProtectionEnabled(bool enabled) async {
    await _sqlite.managers.settings.update(
      (f) =>
          f(id: const Value(1), screenCaptureProtectionEnabled: Value(enabled)),
    );
  }

  Future<void> setExchangeTestnetBasicAuth({
    String? username,
    String? password,
  }) async {
    await _sqlite.managers.settings.update(
      (f) => f(
        id: const Value(1),
        exchangeTestnetBasicAuthUsername: Value(username),
        exchangeTestnetBasicAuthPassword: Value(password),
      ),
    );
  }
}
