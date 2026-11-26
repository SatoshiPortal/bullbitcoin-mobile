import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:secrets/secrets.dart';

import 'data/electrum_store.dart';
import 'data/electrum_import.dart';

import 'dart:async';

import 'package:bull_tor/tor.dart';
import 'package:drift/drift.dart' show GeneratedDatabase, Variable;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show BitcoinTx, WalletConnectionPort;

import 'data/datasources/electrum_remote_datasource.dart';
import 'data/drift_electrum_server_repository.dart';
import 'data/drift_electrum_settings_repository.dart';
import 'data/drift_electrum_transaction_repository.dart';
import 'data/electrum_defaults_provisioner.dart';
import 'data/electrum_server_storage_datasource.dart';
import 'data/electrum_servers_adapter.dart';
import 'data/electrum_settings_storage_datasource.dart';
import 'data/electrum_socket_connector.dart';
import 'data/electrum_tor_session_adapter.dart';
import 'data/server_status_adapter.dart';
import 'data/wallet_connection_policy_impl.dart';
import 'domain/electrum_failure.dart';
import 'domain/electrum_preferences.dart';
import 'domain/electrum_server.dart';
import 'domain/electrum_server_network.dart';
import 'domain/electrum_url_parser.dart';
import 'domain/entities/electrum_settings.dart' show toElectrumOptions;
import 'domain/errors/electrum_fallback_exception.dart';
import 'domain/ports/electrum_servers_port.dart';
import 'domain/ports/electrum_tor_session_port.dart';
import 'domain/ports/server_status_port.dart';
import 'domain/repositories/electrum_server_repository.dart';
import 'domain/repositories/electrum_settings_repository.dart';
import 'domain/repositories/electrum_transaction_repository.dart';
import 'domain/usecases/add_custom_server_usecase.dart';
import 'domain/usecases/check_configured_electrum_usecase.dart';
import 'domain/usecases/load_electrum_server_data_usecase.dart';
import 'domain/usecases/set_advanced_electrum_options_usecase.dart';
import 'domain/value_objects/electrum_endpoint.dart';
import 'domain/value_objects/electrum_options.dart';
import 'domain/value_objects/electrum_server_checks.dart';
import 'domain/value_objects/electrum_server_status.dart';
import 'domain/value_objects/electrum_server_url.dart';

/// Electrum server policy, settings and transaction reads.
class Electrum {
  final ElectrumStore? _store;
  final ElectrumServers servers;
  final ElectrumTransactions transactions;
  final ElectrumDefaultsProvisioner _provisioner;
  final ElectrumServersAdapter _runner;

  const Electrum._(
    this.servers,
    this.transactions,
    this._provisioner,
    this._runner, {
    this._store,
  });

  /// Opens only a prepared owner store; callbacks remain lazy until use.
  @useResult
  static Future<Result<Electrum, ElectrumFailure>> open({
    required File file,
    required RuntimeAdmission admission,
    required ReadElectrumPreferences readPreferences,
    required Tor Function() tor,
  }) async {
    try {
      final opened = await ElectrumStore.open(file, admission, existing: true);
      if (opened case Err(:final failure)) {
        return Err(
          failure is DatabaseNotReady ||
                  failure is DatabaseKeyUnavailable &&
                      failure.reason == DatabaseKeyProblem.locked
              ? const ElectrumStorageNotReadyFailure()
              : const ElectrumLoadFailure(),
        );
      }
      final store = (opened as Ok<ElectrumStore, DatabaseOpenFailure>).value;
      var published = false;
      try {
        final readiness = await readElectrumReadiness(store.database);
        if (readiness case Ok(value: final ready)
            when ready != OwnerReadiness.pending) {
          final capability = _usingDatabase(
            database: store.database,
            readPreferences: readPreferences,
            tor: tor,
            store: store,
          );
          published = true;
          return Ok(capability);
        }
        return readiness is Err<OwnerReadiness, LegacyImportFailure>
            ? const Err(ElectrumLoadFailure())
            : const Err(ElectrumStorageNotReadyFailure());
      } finally {
        if (!published) await store.handle.close();
      }
    } on Exception {
      return const Err(ElectrumLoadFailure());
    }
  }

  @useResult
  Future<Result<void, ElectrumFailure>> close() async {
    try {
      await _store?.handle.close();
      return const Ok(null);
    } on Exception {
      return const Err(ElectrumStorageNotReadyFailure());
    }
  }

  static Electrum _usingDatabase({
    required GeneratedDatabase database,
    required ReadElectrumPreferences readPreferences,
    required Tor Function() tor,
    ElectrumStore? store,
  }) {
    final servers = DriftElectrumServerRepository(
      electrumServerStorageDatasource: ElectrumServerStorageDatasource(
        sqlite: database,
      ),
    );
    final options = DriftElectrumSettingsRepository(
      electrumSettingsStorageDatasource: ElectrumSettingsStorageDatasource(
        sqlite: database,
      ),
    );
    final connector = ElectrumSocketConnector();
    final status = ServerStatusAdapter(connector);
    final torSessions = ElectrumTorSessionAdapter(tor);
    final runner = ElectrumServersAdapter(
      serverRepository: servers,
      settingsRepository: options,
      readPreferences: readPreferences,
      torSessionPort: torSessions,
    );

    return Electrum._(
      ElectrumServers._(
        repository: servers,
        options: ElectrumServerOptions._(options),
        runWithFallback: runner.runWithFallbackResult,
        status: status,
        torSessions: torSessions,
        readPreferences: readPreferences,
      ),
      ElectrumTransactions._(
        runWithFallback: runner.runWithFallbackResult,
        repository: DriftElectrumTransactionRepository(
          datasource: ElectrumRemoteDatasource(
            sqlite: database,
            socketConnector: connector,
          ),
        ),
      ),
      ElectrumDefaultsProvisioner(database),
      runner,
      store: store,
    );
  }
}

/// Composition access for wallet sync, the existing native integrations and
/// explicit foreground storage preparation.
extension ElectrumSetup on Electrum {
  WalletConnectionPort get walletConnections =>
      WalletConnectionPolicyImpl(_runner.runWithFallbackResult);

  ElectrumServersPort get integrationRunner => _runner;

  ElectrumDefaultsProvisioner get foregroundStorage => _provisioner;
}

class ElectrumServers {
  final ElectrumServerRepository _repository;
  final ElectrumServerOptions options;
  final RunElectrumWithFallback _runWithFallback;
  final ServerStatusPort _status;
  final ElectrumTorSessionPort _torSessions;
  final ReadElectrumPreferences _readPreferences;

  const ElectrumServers._({
    required this._repository,
    required this.options,
    required this._runWithFallback,
    required this._status,
    required this._torSessions,
    required this._readPreferences,
  });

  @useResult
  Future<Result<bool, ElectrumFailure>> hasCustomOnionServer({
    required ElectrumServerNetwork network,
  }) async => (await _repository.fetchActiveServers(network: network)).map(
    (servers) => servers.any(
      (server) => server.isCustom && ElectrumServerUrl(server.url).isOnion,
    ),
  );

  @useResult
  Future<Result<List<ElectrumEndpoint>, ElectrumFailure>> fetch({
    required ElectrumServerNetwork network,
  }) async => (await _repository.fetchAll(network: network)).map((servers) {
    servers.sort((a, b) => a.priority.compareTo(b.priority));
    return List.unmodifiable(servers.map(toElectrumEndpoint));
  });

  @useResult
  Future<Result<ElectrumEndpoint, ElectrumFailure>> store(
    String address, {
    required ElectrumServerNetwork network,
    required int priority,
    required bool enableSsl,
  }) async {
    final parsed = ElectrumUrlParser.tryParse(address);
    final port = parsed == null
        ? null
        : int.tryParse(parsed.cleanUrl.split(':').last);
    if (parsed == null ||
        port == null ||
        port < 1 ||
        port > 65535 ||
        priority < 0) {
      return const Err(ElectrumInvalidEndpointFailure());
    }
    final server = ElectrumServer.createCustom(
      host: parsed.cleanUrl.split(':').first,
      port: port,
      network: network,
      priority: priority,
      enableSsl: enableSsl,
    );
    final result = await AddCustomServerUsecase(
      electrumServerRepository: _repository,
      electrumSettingsRepository: options._repository,
      serverStatusPort: _status,
      torSessionPort: _torSessions,
      readPreferences: _readPreferences,
    ).execute(server);
    return result.map(toElectrumEndpoint);
  }

  @useResult
  Future<Result<void, ElectrumFailure>> trash(
    String url, {
    required ElectrumServerNetwork network,
  }) => _repository.delete(url: url, network: network);

  @useResult
  Future<Result<List<ElectrumEndpoint>, ElectrumFailure>> prioritize(
    List<String> urls, {
    required ElectrumServerNetwork network,
  }) async {
    final result = await _repository.reorderCustomServers(
      network: network,
      urls: List.of(urls),
    );
    return result.map(
      (servers) => List.unmodifiable(servers.map(toElectrumEndpoint)),
    );
  }

  /// Runs one refresh and emits the initial unknown statuses and each probe
  /// completion. Canceling stops delivery. In-flight probes release their routes.
  Stream<Result<ElectrumServerChecks, ElectrumFailure>> watchChecks({
    required ElectrumServerNetwork network,
  }) {
    final loader = _loader();
    late final StreamController<Result<ElectrumServerChecks, ElectrumFailure>>
    updates;
    Future<void> refresh() async {
      try {
        final result = await loader.execute(
          network: network,
          onUpdate: (response) => updates.add(Ok(response)),
        );
        if (result case Err(:final failure)) updates.add(Err(failure));
      } catch (error, stack) {
        updates.addError(error, stack);
      } finally {
        unawaited(updates.close());
      }
    }

    updates = StreamController(onListen: () => unawaited(refresh()));
    return updates.stream;
  }

  /// Checks the configured server set using the same fallback policy as sync.
  @useResult
  Future<Result<ElectrumServerStatus, ElectrumFailure>> check({
    required ElectrumServerNetwork network,
  }) => checkConfiguredElectrum(_runWithFallback, _status, network);

  LoadElectrumServerDataUsecase _loader() => LoadElectrumServerDataUsecase(
    electrumServerRepository: _repository,
    electrumSettingsRepository: options._repository,
    serverStatusPort: _status,
    torSessionPort: _torSessions,
    readPreferences: _readPreferences,
  );
}

class ElectrumServerOptions {
  final ElectrumSettingsRepository _repository;

  const ElectrumServerOptions._(this._repository);

  @useResult
  Future<Result<ElectrumOptions, ElectrumFailure>> fetch({
    required ElectrumServerNetwork network,
  }) async =>
      (await _repository.fetchByNetwork(network)).map(toElectrumOptions);

  @useResult
  Future<Result<void, ElectrumFailure>> store(ElectrumOptions options) =>
      SetAdvancedElectrumOptionsUsecase(electrumSettingsRepository: _repository)
          .execute(options);
}

/// Reads parsed Bitcoin transactions through the active server policy.
class ElectrumTransactions {
  final RunElectrumWithFallback _runWithFallback;
  final ElectrumTransactionRepository _repository;

  const ElectrumTransactions._({
    required this._runWithFallback,
    required this._repository,
  });

  @useResult
  Future<Result<BitcoinTx, ElectrumFailure>> fetch(
    String txid, {
    required BitcoinNetwork network,
  }) async {
    final serverNetwork = switch (network) {
      BitcoinNetwork.mainnet => ElectrumServerNetwork.bitcoinMainnet,
      BitcoinNetwork.testnet => ElectrumServerNetwork.bitcoinTestnet,
      BitcoinNetwork.regtest => ElectrumServerNetwork.bitcoinRegtest,
      BitcoinNetwork.signet => null,
    };
    if (serverNetwork == null) {
      return const Err(ElectrumUnsupportedNetworkFailure());
    }
    try {
      return await _runWithFallback(
        network: serverNetwork,
        operation: (connection) =>
            _repository.fetch(connection: connection, txid: txid),
      );
    } on NoElectrumServersConfiguredException catch (failure) {
      return Err(ElectrumNoTransactionServersFailure(failure.network));
    } on AllElectrumServersFailedException {
      return Err(ElectrumTransactionFetchFailure(txid));
    } on Exception catch (failure) {
      return Err(ElectrumUnexpectedFailure(failure.runtimeType.toString()));
    }
  }
}

/// Constructs an isolated test capability without owning the injected database.
@visibleForTesting
Electrum createElectrumForTesting({
  required GeneratedDatabase database,
  required ReadElectrumPreferences readPreferences,
  required Tor Function() tor,
}) => Electrum._usingDatabase(
  database: database,
  readPreferences: readPreferences,
  tor: tor,
);

/// Test-only inspection of the actual encrypted owner cache.
@visibleForTesting
Future<bool> hasCachedElectrumTransactionForTesting(
  Electrum owner,
  String txid,
) async {
  final store = owner._store;
  if (store == null) throw StateError('Owner store required');
  final rows = await store.database
      .customSelect(
        'SELECT 1 FROM transactions WHERE txid = ?',
        variables: [Variable(txid)],
      )
      .get();
  return rows.isNotEmpty;
}

@visibleForTesting
Future<void> clearElectrumCacheForTesting(Electrum owner) async {
  final store = owner._store;
  if (store == null) throw StateError('Owner store required');
  await store.database.customStatement('DELETE FROM transactions');
}
