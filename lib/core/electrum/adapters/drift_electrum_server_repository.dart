import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_server_model.dart';
import 'package:bb_mobile/core/utils/logger.dart';
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
    } catch (e, st) {
      log.severe(
        message: 'Failed to save electrum server',
        error: e,
        trace: st,
      );
      return Err(ElectrumSaveFailure(e.toString()));
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
    } catch (e, st) {
      log.severe(
        message: 'Failed to batch save electrum servers',
        error: e,
        trace: st,
      );
      return Err(ElectrumSaveFailure(e.toString()));
    }
  }

  @override
  Future<Result<ElectrumServer?, ElectrumFailure>> fetchByUrl(
    String url,
  ) async {
    try {
      final server = await _datasource.fetchByUrl(url);
      return Ok(server?.toEntity());
    } catch (e, st) {
      log.severe(
        message: 'Failed to fetch electrum server by url',
        error: e,
        trace: st,
      );
      return Err(ElectrumLoadFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<ElectrumServer>, ElectrumFailure>> fetchAll({
    bool? isTestnet,
    bool? isLiquid,
    bool? isCustom,
  }) async {
    try {
      final models = await _datasource.fetchAllServers(
        isTestnet: isTestnet,
        isLiquid: isLiquid,
        isCustom: isCustom,
      );
      return Ok(models.map((e) => e.toEntity()).toList());
    } catch (e, st) {
      log.severe(
        message: 'Failed to fetch all electrum servers',
        error: e,
        trace: st,
      );
      return Err(ElectrumLoadFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<ElectrumServer>, ElectrumFailure>> fetchCustomServers({
    required ElectrumServerNetwork network,
  }) async {
    try {
      final models = await _datasource.fetchCustomServersByNetwork(network);
      return Ok(models.map((e) => e.toEntity()).toList());
    } catch (e, st) {
      log.severe(
        message: 'Failed to fetch custom electrum servers',
        error: e,
        trace: st,
      );
      return Err(ElectrumLoadFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<ElectrumServer>, ElectrumFailure>> fetchDefaultServers({
    required ElectrumServerNetwork network,
  }) async {
    try {
      final models = await _datasource.fetchDefaultServersByNetwork(network);
      return Ok(models.map((e) => e.toEntity()).toList());
    } catch (e, st) {
      log.severe(
        message: 'Failed to fetch default electrum servers',
        error: e,
        trace: st,
      );
      return Err(ElectrumLoadFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<ElectrumServer>, ElectrumFailure>> fetchActiveServers({
    required ElectrumServerNetwork network,
  }) async {
    final result = await fetchAll(
      isTestnet: network.isTestnet,
      isLiquid: network.isLiquid,
    );
    return result.map((servers) {
      final customServers = servers.where((s) => s.isCustom).toList();
      final activeServers = customServers.isNotEmpty ? customServers : servers;
      activeServers.sort((a, b) => a.priority.compareTo(b.priority));
      return activeServers;
    });
  }

  @override
  Future<Result<void, ElectrumFailure>> delete({required String url}) async {
    try {
      await _datasource.deleteServer(url);
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to delete electrum server',
        error: e,
        trace: st,
      );
      return Err(ElectrumDeleteFailure(e.toString()));
    }
  }
}
