import 'package:bb_mobile/features/electrum_settings/domain/regtest_electrum_profile.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_failure.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_environment.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_storage_readiness_port.dart';
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';

/// Feature-owned, local-only bootstrap of the two regtest tables.
/// Only the explicit foreground entry point may write.
final class ElectrumDefaultsProvisioner
    implements ElectrumStorageReadinessPort {
  final SqliteDatabase _database;
  final bool _readOnly;
  Future<Result<void, ElectrumFailure>>? _preparing;
  NetworkEnv? _prepared;
  NetworkEnv? _preparingEnvironment;
  RegtestElectrumProfile? _regtestProfile;
  String? _preparingHost;

  ElectrumDefaultsProvisioner(this._database, {this._readOnly = false});

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
    final pending = _preparing;
    if (pending != null) {
      if (_preparingEnvironment != environment ||
          _preparingHost != profile?.host) {
        return const Err(ElectrumStorageNotReadyFailure());
      }
      return pending;
    }
    _preparingEnvironment = environment;
    _preparingHost = profile?.host;
    final preparation = _prepare(environment, profile);
    _preparing = preparation;
    try {
      return await preparation;
    } finally {
      _preparing = null;
    }
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
            final defaults = await _database.managers.electrumServers
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
            await _database.managers.electrumServers
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
      _regtestProfile = environment == NetworkEnv.regtest
          ? regtestProfile
          : null;
      _prepared = environment;
      return const Ok(null);
    } on Exception {
      return const Err(ElectrumSaveFailure());
    }
  }

  @override
  Future<Result<void, ElectrumFailure>> requireReady(
    ElectrumServerNetwork network,
  ) async {
    final pending = _preparing;
    if (pending != null) {
      final result = await pending;
      if (result case Err(:final failure)) return Err(failure);
    }
    final requested = network.environment.networkEnv;
    // Storage readiness covers both production catalogs. Runtime admission
    // remains responsible for the selected context during a hot switch.
    final productionReady =
        (_prepared == NetworkEnv.mainnet || _prepared == NetworkEnv.testnet) &&
        (requested == NetworkEnv.mainnet || requested == NetworkEnv.testnet);
    if (!_readOnly && _prepared != requested && !productionReady) {
      return const Err(ElectrumStorageNotReadyFailure());
    }
    try {
      // Headless callers check the on-disk schema before opening Drift. This
      // second check never repairs missing rows and checks both chains.
      final networks = [
        ElectrumServerNetwork.fromNetworkEnv(
          network.environment.networkEnv,
          isLiquid: false,
        ),
        ElectrumServerNetwork.fromNetworkEnv(
          network.environment.networkEnv,
          isLiquid: true,
        ),
      ];
      for (final expected in networks) {
        final settings = await _database.managers.electrumSettings
            .filter((f) => f.network(expected))
            .getSingleOrNull();
        final servers = await _database.managers.electrumServers
            .filter((f) => f.network.equals(expected.storageName))
            .get();
        if (settings == null || servers.isEmpty) {
          return const Err(ElectrumStorageNotReadyFailure());
        }
        if (network.environment == ElectrumEnvironment.regtest &&
            !servers.any((server) => server.isCustom)) {
          final profile =
              _regtestProfile ?? RegtestElectrumProfile.fromBuildEnvironment();
          if (!servers.any(
            (server) =>
                server.url == profile.endpoint(isLiquid: expected.isLiquid),
          )) {
            return const Err(ElectrumStorageNotReadyFailure());
          }
        }
      }
      return const Ok(null);
    } on Exception {
      return const Err(ElectrumLoadFailure());
    }
  }
}
