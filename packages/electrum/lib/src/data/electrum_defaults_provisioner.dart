import 'package:electrum/src/domain/regtest_electrum_profile.dart';
import 'package:electrum/src/storage/electrum_dao.dart';
import 'package:electrum/src/storage/electrum_servers_table.drift.dart';
import 'package:electrum/src/storage/electrum_settings_table.drift.dart';
import 'package:electrum/src/domain/electrum_failure.dart';
import 'package:electrum/src/domain/electrum_server_network.dart';
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';

/// Feature-owned, local-only bootstrap of the two regtest tables.
/// Only the explicit foreground entry point may write.
class ElectrumDefaultsProvisioner {
  final ElectrumDao _database;
  final bool _readOnly;
  ElectrumDefaultsProvisioner(
    GeneratedDatabase database, {
    this._readOnly = false,
  }) : _database = ElectrumDao(database);

  Future<Result<void, ElectrumFailure>> prepareForegroundStorage(
    NetworkEnv environment, {
    RegtestElectrumProfile? regtestProfile,
  }) async {
    if (_readOnly || environment == NetworkEnv.signet) {
      return const Err(ElectrumStorageNotReadyFailure());
    }
    final RegtestElectrumProfile? profile;
    try {
      profile = environment == NetworkEnv.regtest
          ? regtestProfile ?? RegtestElectrumProfile.fromBuildEnvironment()
          : null;
    } on FormatException {
      return const Err(ElectrumLoadFailure());
    }
    return _prepare(environment, profile);
  }

  Future<Result<void, ElectrumFailure>> _prepare(
    NetworkEnv environment,
    RegtestElectrumProfile? regtestProfile,
  ) async {
    try {
      if (environment == NetworkEnv.regtest) {
        final profile =
            regtestProfile ?? RegtestElectrumProfile.fromBuildEnvironment();
        await _database.transaction(() async {
          for (final network in [
            ElectrumServerNetwork.bitcoinRegtest,
            ElectrumServerNetwork.liquidRegtest,
          ]) {
            final endpoint = profile.endpoint(isLiquid: network.isLiquid);
            final defaults = await _database.serverRows
                .filter(
                  (f) =>
                      f.network.equals(network.storageName) & f.isCustom(false),
                )
                .get();
            final priority = defaults.isEmpty ? 0 : defaults.first.priority;
            await _database
                .into(_database.electrumSettings)
                .insert(
                  ElectrumSettingsRow(
                    network: network,
                    validateDomain: true,
                    stopGap: 20,
                    timeout: 5,
                    retry: 5,
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
            await _database
                .into(_database.electrumServers)
                .insert(
                  ElectrumServerRow(
                    url: endpoint,
                    network: network.storageName,
                    priority: priority,
                    isCustom: false,
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
            // Defaults are profile-owned; custom endpoints are never changed.
            await _database.serverRows
                .filter(
                  (f) =>
                      f.network.equals(network.storageName) &
                      f.isCustom(false) &
                      f.url.not.equals(endpoint),
                )
                .delete();
          }
        });
      }
      return const Ok(null);
    } on Exception {
      return const Err(ElectrumSaveFailure());
    }
  }
}
