import 'package:bb_mobile/features/electrum_settings/domain/electrum_server.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_failure.dart';
import 'package:bb_mobile/features/electrum_settings/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:bb_mobile/features/electrum_settings/data/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/features/electrum_settings/data/models/electrum_server_model.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';

class DriftElectrumServerRepository implements ElectrumServerRepository {
  final ElectrumServerStorageDatasource _datasource;

  DriftElectrumServerRepository({
    required ElectrumServerStorageDatasource electrumServerStorageDatasource,
  }) : _datasource = electrumServerStorageDatasource;

  @override
  Future<Result<void, ElectrumFailure>> save(ElectrumServer server) async {
    try {
      final model = ElectrumServerModel.fromEntity(server);
      await _datasource.store(model);
      return const Ok(null);
    } on Exception {
      log.warning('Failed to save electrum server');
      return const Err(ElectrumSaveFailure());
    }
  }

  @override
  Future<Result<void, ElectrumFailure>> batchSave(
    List<ElectrumServer> servers,
  ) async {
    try {
      final models = servers
          .map((e) => ElectrumServerModel.fromEntity(e))
          .toList();
      await _datasource.storeBatch(models);
      return const Ok(null);
    } on Exception {
      log.warning('Failed to batch save electrum servers');
      return const Err(ElectrumSaveFailure());
    }
  }

  @override
  Future<Result<ElectrumServer?, ElectrumFailure>> fetchByUrl(
    String url, {
    required ElectrumServerNetwork network,
  }) async {
    try {
      final server = await _datasource.fetchByUrl(url, network: network);
      return Ok(server?.toEntity());
    } on Exception {
      log.warning('Failed to fetch electrum server by url');
      return const Err(ElectrumLoadFailure());
    }
  }

  @override
  Future<Result<List<ElectrumServer>, ElectrumFailure>> fetchAll({
    ElectrumServerNetwork? network,
    bool? isCustom,
  }) async {
    try {
      final models = await _datasource.fetchAllServers(
        network: network,
        isCustom: isCustom,
      );
      return Ok(models.map((e) => e.toEntity()).toList());
    } on Exception {
      log.warning('Failed to fetch all electrum servers');
      return const Err(ElectrumLoadFailure());
    }
  }

  @override
  Future<Result<List<ElectrumServer>, ElectrumFailure>> fetchCustomServers({
    required ElectrumServerNetwork network,
  }) async {
    try {
      final models = await _datasource.fetchCustomServersByNetwork(network);
      return Ok(models.map((e) => e.toEntity()).toList());
    } on Exception {
      log.warning('Failed to fetch custom electrum servers');
      return const Err(ElectrumLoadFailure());
    }
  }

  @override
  Future<Result<List<ElectrumServer>, ElectrumFailure>> fetchDefaultServers({
    required ElectrumServerNetwork network,
  }) async {
    try {
      final models = await _datasource.fetchDefaultServersByNetwork(network);
      return Ok(models.map((e) => e.toEntity()).toList());
    } on Exception {
      log.warning('Failed to fetch default electrum servers');
      return const Err(ElectrumLoadFailure());
    }
  }

  @override
  Future<Result<List<ElectrumServer>, ElectrumFailure>> fetchActiveServers({
    required ElectrumServerNetwork network,
  }) async {
    // TODO(SatoshiPortal/lwk-dart#96): keep Liquid regtest unavailable until
    // the pinned SDK supports the concrete chain.
    if (network == ElectrumServerNetwork.liquidRegtest) {
      return const Err(ElectrumUnsupportedNetworkFailure());
    }
    final result = await fetchAll(network: network);
    return result.map((servers) {
      final customServers = servers.where((s) => s.isCustom).toList();
      final activeServers = customServers.isNotEmpty ? customServers : servers;
      activeServers.sort((a, b) => a.priority.compareTo(b.priority));
      return activeServers;
    });
  }

  @override
  Future<Result<void, ElectrumFailure>> delete({
    required String url,
    required ElectrumServerNetwork network,
  }) async {
    try {
      await _datasource.deleteServer(url, network: network);
      return const Ok(null);
    } on Exception {
      log.warning('Failed to delete electrum server');
      return const Err(ElectrumDeleteFailure());
    }
  }
}
