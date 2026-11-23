import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:drift/drift.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart';

import '../domain/settings_entity.dart';
import 'owner_settings_table.dart';
import 'owner_settings_table.drift.dart' show OwnerSettingsRow;
import 'preferences_dao.drift.dart';
import 'recoverbull_permissions_table.dart';
import 'settings_model.dart';

@DriftAccessor(
  tables: [
    OwnerSettings,
    RecoverbullPermissions,
    RecoverbullPermissionOverrides,
  ],
)
class PreferencesDao extends DatabaseAccessor<GeneratedDatabase>
    with $PreferencesDaoMixin {
  PreferencesDao(super.attachedDatabase);

  Stream<OwnerSettingsRow?> watchSettings() => (select(
    ownerSettings,
  )..where((row) => row.id.equals(1))).watchSingleOrNull();

  Future<({bool granted, int revision})?> readRecoverBullPermission({
    required bool regtest,
  }) async {
    final current =
        await (select(recoverbullPermissionOverrides)..where(
              (row) => row.family.equals(regtest ? 'regtest' : 'default'),
            ))
            .getSingleOrNull();
    if (current != null) {
      return (granted: current.isPermissionGranted, revision: current.revision);
    }
    if (regtest) return (granted: false, revision: 0);
    final legacy = await (select(
      recoverbullPermissions,
    )..where((row) => row.id.equals(1))).getSingleOrNull();
    if (legacy == null) return null;
    return (granted: legacy.isPermissionGranted, revision: 0);
  }

  Future<void> setRecoverBullPermission(
    bool permission, {
    required bool regtest,
  }) async {
    await customStatement(
      'INSERT INTO recoverbull_permission_overrides '
      '(family, is_permission_granted, revision) VALUES (?, ?, 1) '
      'ON CONFLICT (family) DO UPDATE SET '
      'is_permission_granted = excluded.is_permission_granted, '
      'revision = recoverbull_permission_overrides.revision + 1',
      [regtest ? 'regtest' : 'default', permission ? 1 : 0],
    );
  }

  /// Repair persisted developer authorization before exposing the active network.
  /// The transaction prevents a concurrent settings write between read and repair.
  Future<SettingsModel> fetch() => transaction(() async {
    var row = await managers.ownerSettings
        .filter((f) => f.id(1))
        .getSingleOrNull();
    if (row == null) throw const PreferencesMissingRowException();
    if (row.environment != Environment.mainnet.name &&
        (!row.isSuperuser || !row.isDevModeEnabled)) {
      await setIsDevMode(false);
      row = await managers.ownerSettings
          .filter((f) => f.id(1))
          .getSingleOrNull();
      if (row == null) throw const PreferencesMissingRowException();
      log.warning('Active network restored category=developerAuthorization');
    }
    if (!Environment.values.any((value) => value.name == row?.environment) ||
        !BitcoinUnit.values.any((value) => value.name == row?.bitcoinUnit)) {
      throw const FormatException('Invalid stored preferences');
    }
    return SettingsModel.fromSqlite(row);
  });

  Future<void> _requireUpdated(Future<int> pending) async {
    if (await pending != 1) throw const PreferencesMissingRowException();
  }

  Future<void> setEnvironment(Environment env) async {
    await _requireUpdated(
      managers.ownerSettings
          .filter((row) => row.id(1))
          .update((f) => f(id: const Value(1), environment: Value(env.name))),
    );
  }

  Future<void> setStartAmountsInFiat(bool fiat) async {
    await _requireUpdated(
      managers.ownerSettings
          .filter((row) => row.id(1))
          .update(
            (f) => f(id: const Value(1), startAmountsInFiat: Value(fiat)),
          ),
    );
  }

  Future<void> setBitcoinUnit(BitcoinUnit bitcoinUnit) async {
    await _requireUpdated(
      managers.ownerSettings
          .filter((row) => row.id(1))
          .update(
            (f) => f(id: const Value(1), bitcoinUnit: Value(bitcoinUnit.name)),
          ),
    );
  }

  Future<void> setLanguage(Language language) async {
    await _requireUpdated(
      managers.ownerSettings
          .filter((row) => row.id(1))
          .update((f) => f(id: const Value(1), language: Value(language.name))),
    );
  }

  Future<void> setCurrency(String currencyCode) async {
    await _requireUpdated(
      managers.ownerSettings
          .filter((row) => row.id(1))
          .update((f) => f(id: const Value(1), currency: Value(currencyCode))),
    );
  }

  Future<void> setHideAmounts(bool hide) async {
    await _requireUpdated(
      managers.ownerSettings
          .filter((row) => row.id(1))
          .update((f) => f(id: const Value(1), hideAmounts: Value(hide))),
    );
  }

  Future<void> setIsSuperuser(bool isSuperuser) async {
    await _requireUpdated(
      managers.ownerSettings
          .filter((row) => row.id(1))
          .update(
            (f) => f(id: const Value(1), isSuperuser: Value(isSuperuser)),
          ),
    );
  }

  Future<void> setIsDevMode(bool isEnabled) async {
    await _requireUpdated(
      managers.ownerSettings
          .filter((row) => row.id(1))
          .update(
            (f) => f(
              id: const Value(1),
              isDevModeEnabled: Value(isEnabled),
              environment: isEnabled
                  ? const Value.absent()
                  : Value(Environment.mainnet.name),
            ),
          ),
    );
  }

  Future<void> setTorProxy({required bool enabled, required int port}) async {
    await _requireUpdated(
      managers.ownerSettings
          .filter((row) => row.id(1))
          .update(
            (f) => f(
              id: const Value(1),
              useTorProxy: Value(enabled),
              torProxyPort: Value(port),
            ),
          ),
    );
  }

  Future<void> setTorTransportMode(TorTransportMode mode) async {
    await _requireUpdated(
      managers.ownerSettings
          .filter((row) => row.id(1))
          .update(
            (f) => f(id: const Value(1), torTransportMode: Value(mode.name)),
          ),
    );
  }

  Future<void> setLastSuccessfulTorTransport(TorTransport transport) async {
    await _requireUpdated(
      managers.ownerSettings
          .filter((row) => row.id(1))
          .update(
            (f) => f(
              id: const Value(1),
              lastSuccessfulTorTransport: Value(transport.name),
            ),
          ),
    );
  }

  Future<void> setThemeMode(AppThemeMode themeMode) async {
    await _requireUpdated(
      managers.ownerSettings
          .filter((row) => row.id(1))
          .update(
            (f) => f(id: const Value(1), themeMode: Value(themeMode.name)),
          ),
    );
  }

  Future<void> setErrorReportingEnabled(bool enabled) async {
    await _requireUpdated(
      managers.ownerSettings
          .filter((row) => row.id(1))
          .update(
            (f) =>
                f(id: const Value(1), isErrorReportingEnabled: Value(enabled)),
          ),
    );
  }

  Future<void> setScreenCaptureProtectionEnabled(bool enabled) async {
    await _requireUpdated(
      managers.ownerSettings
          .filter((row) => row.id(1))
          .update(
            (f) => f(
              id: const Value(1),
              screenCaptureProtectionEnabled: Value(enabled),
            ),
          ),
    );
  }
}

final class PreferencesMissingRowException implements Exception {
  const PreferencesMissingRowException();
}
