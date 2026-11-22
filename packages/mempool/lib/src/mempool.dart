import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:secrets/secrets.dart';

import 'data/mempool_store.dart';
import 'data/mempool_import.dart';

import 'package:bull_tor/tor.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'data/drift_mempool_server_repository.dart';
import 'data/http_mempool_server_validator.dart';
import 'data/mempool_dao.dart';
import 'data/mempool_tor_session_adapter.dart';
import 'domain/entities/mempool_server.dart';
import 'domain/entities/mempool_server_selection.dart';
import 'domain/mempool_failure.dart';
import 'domain/ports/mempool_server_validator_port.dart';
import 'domain/repositories/mempool_server_repository.dart';
import 'domain/usecases/get_active_mempool_server_usecase.dart';
import 'domain/usecases/load_mempool_server_data_usecase.dart';
import 'domain/usecases/set_custom_mempool_server_usecase.dart';
import 'domain/value_objects/mempool_server_network.dart';

part 'mempool_links.dart';
part 'mempool_servers.dart';

/// Configured servers and explorer links for Bitcoin and Liquid.
class Mempool {
  final MempoolStore? _store;
  final MempoolLinks links;
  final MempoolServerSettings servers;

  const Mempool._({required this.links, required this.servers, this._store});

  @useResult
  static Future<Result<Mempool, MempoolFailure>> open({
    required File file,
    required RuntimeAdmission admission,
    required Tor Function() tor,
    required TorHttpClientFactory torHttp,
  }) async {
    final opened = await MempoolStore.open(file, admission, existing: true);
    switch (opened) {
      case Err(:final failure):
        return Err(
          MempoolStorageUnavailableFailure(
            deferred:
                failure is DatabaseNotReady ||
                failure is DatabaseKeyUnavailable &&
                    failure.reason == DatabaseKeyProblem.locked,
          ),
        );
      case Ok(:final value):
        final readiness = await readMempoolReadiness(value.database);
        if (readiness case Ok(value: final ready)
            when ready != OwnerReadiness.pending) {
          return Ok(
            _usingDatabase(
              database: value.database,
              tor: tor,
              torHttp: torHttp,
              store: value,
            ),
          );
        }
        await value.handle.close();
        return const Err(MempoolStorageUnavailableFailure(deferred: true));
    }
  }

  @useResult
  Future<Result<void, MempoolFailure>> close() async {
    try {
      await _store?.handle.close();
      return const Ok(null);
    } on Exception {
      return const Err(MempoolStorageUnavailableFailure(deferred: true));
    }
  }

  @visibleForTesting
  static Mempool testing({
    required GeneratedDatabase database,
    required Tor Function() tor,
    required TorHttpClientFactory torHttp,
  }) => _usingDatabase(database: database, tor: tor, torHttp: torHttp);

  static Mempool _usingDatabase({
    MempoolStore? store,
    required GeneratedDatabase database,
    required Tor Function() tor,
    required TorHttpClientFactory torHttp,
  }) {
    final repository = DriftMempoolServerRepository(
      mempoolServerStorageDatasource: MempoolDao(database),
    );
    final activeServer = GetActiveMempoolServerUsecase(
      serverRepository: repository,
    );
    return Mempool._(
      store: store,
      links: MempoolLinks._(activeServer),
      servers: MempoolServerSettings._(
        repository: repository,
        activeServer: activeServer,
        validator: HttpMempoolServerValidator(
          torSessionPort: MempoolTorSessionAdapter(tor),
          torHttpClientFactory: torHttp,
        ),
      ),
    );
  }
}
