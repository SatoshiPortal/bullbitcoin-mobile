import 'package:electrum/src/domain/electrum_default_endpoints.dart';

import '../domain/regtest_electrum_profile.dart';

import 'package:electrum/src/domain/electrum_server_network.dart';
import 'package:electrum/src/data/models/electrum_server_model.dart';
import 'package:electrum/src/storage/electrum_dao.dart';
import 'package:electrum/src/storage/electrum_servers_table.drift.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart';

class ElectrumServerStorageDatasource {
  final ElectrumDao _sqlite;
  final RegtestElectrumProfile? _regtestProfile;

  ElectrumServerStorageDatasource({
    required GeneratedDatabase sqlite,
    this._regtestProfile,
  }) : _sqlite = ElectrumDao(sqlite);

  Future<void> store(ElectrumServerModel server) async {
    await _sqlite
        .into(_sqlite.electrumServers)
        .insertOnConflictUpdate(server.toSqlite());
    log.fine('Electrum server stored network=${server.network}');
  }

  Future<void> _storeBatch(List<ElectrumServerModel> servers) async {
    await _sqlite.batch((batch) {
      for (final server in servers) {
        batch.insert(
          _sqlite.electrumServers,
          server.toSqlite(),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    log.fine('Electrum server priorities stored count=${servers.length}');
  }

  Future<List<ElectrumServerModel>?> reorderCustomServers(
    ElectrumServerNetwork network,
    List<String> urls,
  ) => _sqlite.transaction(() async {
    final customRows = _sqlite.serverRows.filter(
      (row) => row.network.equals(network.storageName) & row.isCustom(true),
    );
    final current = {for (final row in await customRows.get()) row.url: row};
    final ordered = urls.toSet();
    if (ordered.length != urls.length ||
        ordered.length != current.length ||
        !ordered.every(current.containsKey)) {
      return null;
    }

    final rows = <ElectrumServerRow>[];
    for (final (priority, url) in urls.indexed) {
      final row = current[url];
      if (row == null) return null;
      rows.add(row.copyWith(priority: priority));
    }
    final models = rows.map(ElectrumServerModel.fromSqlite).toList();
    await _storeBatch(models);
    return models;
  });

  Future<ElectrumServerModel?> fetchByUrl(
    String url, {
    required ElectrumServerNetwork network,
  }) async {
    final row = await _sqlite.serverRows
        .filter(
          (f) => f.url.equals(url) & f.network.equals(network.storageName),
        )
        .getSingleOrNull();
    return row == null ? null : ElectrumServerModel.fromSqlite(row);
  }

  Future<List<ElectrumServerModel>> fetchAllServers({
    ElectrumServerNetwork? network,
    bool? isCustom,
  }) async {
    var query = _sqlite.serverRows.filter((f) => const Constant(true));
    if (network != null) {
      query = query.filter((f) => f.network.equals(network.storageName));
    }
    if (isCustom != null) query = query.filter((f) => f.isCustom(isCustom));
    final rows = await query.get();
    return rows.map(ElectrumServerModel.fromSqlite).toList();
  }

  Future<List<ElectrumServerModel>> fetchDefaultServersByNetwork(
    ElectrumServerNetwork network,
  ) => fetchAllServers(network: network, isCustom: false);

  Future<List<ElectrumServerModel>> fetchCustomServersByNetwork(
    ElectrumServerNetwork network,
  ) => fetchAllServers(network: network, isCustom: true);

  Future<bool> deleteServer(
    String url, {
    required ElectrumServerNetwork network,
  }) async {
    return _sqlite.transaction(() async {
      final existing = await _sqlite.serverRows
          .filter(
            (f) => f.url.equals(url) & f.network.equals(network.storageName),
          )
          .getSingleOrNull();
      if (existing?.isCustom != true) return false;
      final managed = _managedDefault(url, network);
      final deleted = await _sqlite.serverRows
          .filter(
            (f) => f.url.equals(url) & f.network.equals(network.storageName),
          )
          .delete();
      if (deleted > 0 && managed != null) {
        await _sqlite
            .into(_sqlite.electrumServers)
            .insert(
              ElectrumServerRow(
                url: managed.$1,
                network: network.storageName,
                priority: managed.$2,
                isCustom: false,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
      log.fine('Electrum server deleted network=$network count=$deleted');
      return deleted > 0;
    });
  }

  (String, int)? _managedDefault(String url, ElectrumServerNetwork network) {
    final defaults = switch (network) {
      ElectrumServerNetwork.bitcoinMainnet => [
        (ElectrumDefaultEndpoints.fulcrumElectrumUrl, 0),
        (ElectrumDefaultEndpoints.bbElectrumUrl, 1),
        (ElectrumDefaultEndpoints.publicElectrumUrl, 2),
      ],
      ElectrumServerNetwork.bitcoinTestnet => [
        (ElectrumDefaultEndpoints.publicElectrumTestUrl, 0),
      ],
      ElectrumServerNetwork.liquidMainnet => [
        (ElectrumDefaultEndpoints.bbLiquidElectrumUrlPath, 0),
        (ElectrumDefaultEndpoints.publicLiquidElectrumUrlPath, 1),
      ],
      ElectrumServerNetwork.liquidTestnet => [
        (ElectrumDefaultEndpoints.publicliquidElectrumTestUrlPath, 0),
      ],
      ElectrumServerNetwork.bitcoinRegtest ||
      ElectrumServerNetwork.liquidRegtest => [
        (
          (_regtestProfile ?? RegtestElectrumProfile.fromBuildEnvironment())
              .endpoint(isLiquid: network.isLiquid),
          0,
        ),
      ],
    };
    return defaults.where((entry) => entry.$1 == url).firstOrNull;
  }
}
