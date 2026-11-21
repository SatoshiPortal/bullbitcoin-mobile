import 'package:preferences/src/data/settings_model.dart';
import 'package:preferences/src/domain/settings_entity.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:drift/drift.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart';

import 'dismissed_announcements_table.dart';
import 'dismissed_announcements_table.drift.dart'
    show DismissedAnnouncementsCompanion;
import 'preferences_dao.drift.dart';
import 'recoverbull_table.dart';
import 'settings_table.dart';
import 'settings_table.drift.dart' show SettingsRow;

@DriftAccessor(tables: [Settings, Recoverbull, DismissedAnnouncements])
class PreferencesDao extends DatabaseAccessor<GeneratedDatabase>
    with $PreferencesDaoMixin {
  PreferencesDao(super.attachedDatabase);

  Stream<SettingsRow?> watchSettings() =>
      (select(settings)..where((row) => row.id.equals(1))).watchSingleOrNull();

  Future<({String url, bool permissionGranted})?> readRecoverBull() async {
    final row = await (select(
      recoverbull,
    )..where((row) => row.id.equals(1))).getSingleOrNull();
    if (row == null) return null;
    return (url: row.url, permissionGranted: row.isPermissionGranted);
  }

  Future<List<({String id, DateTime dismissedAt})>> readDismissals() async =>
      (await select(dismissedAnnouncements).get())
          .map((row) => (id: row.announcementId, dismissedAt: row.dismissedAt))
          .toList();

  Future<void> dismissAnnouncement(String id, DateTime dismissedAt) async {
    await into(dismissedAnnouncements).insertOnConflictUpdate(
      DismissedAnnouncementsCompanion.insert(
        announcementId: id,
        dismissedAt: dismissedAt,
      ),
    );
  }

  Future<void> store(SettingsModel model) async {
    await into(settings).insert(model.toSqlite());
  }

  /// Repair persisted developer authorization before exposing the active network.
  /// The transaction prevents a concurrent settings write between read and repair.
  Future<SettingsModel> fetch() => transaction(() async {
    var row = await managers.settings.filter((f) => f.id(1)).getSingle();
    if (row.environment != Environment.mainnet.name &&
        (!row.isSuperuser || !row.isDevModeEnabled)) {
      await setIsDevMode(false);
      row = await managers.settings.filter((f) => f.id(1)).getSingle();
      log.warning('Active network restored category=developerAuthorization');
    }
    return SettingsModel.fromSqlite(row);
  });

  Future<void> setEnvironment(Environment env) async {
    await managers.settings.update(
      (f) => f(id: const Value(1), environment: Value(env.name)),
    );
  }

  Future<void> setStartAmountsInFiat(bool fiat) async {
    await managers.settings.update(
      (f) => f(id: const Value(1), startAmountsInFiat: Value(fiat)),
    );
  }

  Future<void> setBitcoinUnit(BitcoinUnit bitcoinUnit) async {
    await managers.settings.update(
      (f) => f(id: const Value(1), bitcoinUnit: Value(bitcoinUnit.name)),
    );
  }

  Future<void> setLanguage(Language language) async {
    await managers.settings.update(
      (f) => f(id: const Value(1), language: Value(language.name)),
    );
  }

  Future<void> setCurrency(String currencyCode) async {
    await managers.settings.update(
      (f) => f(id: const Value(1), currency: Value(currencyCode)),
    );
  }

  Future<void> setHideAmounts(bool hide) async {
    await managers.settings.update(
      (f) => f(id: const Value(1), hideAmounts: Value(hide)),
    );
  }

  Future<void> setIsSuperuser(bool isSuperuser) async {
    await managers.settings.update(
      (f) => f(id: const Value(1), isSuperuser: Value(isSuperuser)),
    );
  }

  Future<void> setIsDevMode(bool isEnabled) async {
    await managers.settings.update(
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
    await managers.settings.update(
      (f) => f(
        id: const Value(1),
        useTorProxy: Value(enabled),
        torProxyPort: Value(port),
      ),
    );
  }

  Future<void> setTorTransportMode(TorTransportMode mode) async {
    await managers.settings.update(
      (f) => f(id: const Value(1), torTransportMode: Value(mode.name)),
    );
  }

  Future<void> setLastSuccessfulTorTransport(TorTransport transport) async {
    await managers.settings.update(
      (f) => f(
        id: const Value(1),
        lastSuccessfulTorTransport: Value(transport.name),
      ),
    );
  }

  Future<void> setThemeMode(AppThemeMode themeMode) async {
    await managers.settings.update(
      (f) => f(id: const Value(1), themeMode: Value(themeMode.name)),
    );
  }

  Future<void> setErrorReportingEnabled(bool enabled) async {
    await managers.settings.update(
      (f) => f(id: const Value(1), isErrorReportingEnabled: Value(enabled)),
    );
  }

  Future<void> setScreenCaptureProtectionEnabled(bool enabled) async {
    await managers.settings.update(
      (f) =>
          f(id: const Value(1), screenCaptureProtectionEnabled: Value(enabled)),
    );
  }

  Future<void> setExchangeTestnetBasicAuth({
    String? username,
    String? password,
  }) async {
    await managers.settings.update(
      (f) => f(
        id: const Value(1),
        exchangeTestnetBasicAuthUsername: Value(username),
        exchangeTestnetBasicAuthPassword: Value(password),
      ),
    );
  }
}
