import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_server_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_server_model.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';

class DriftMempoolServerRepository implements MempoolServerRepository {
  final MempoolServerStorageDatasource _datasource;

  DriftMempoolServerRepository({
    required MempoolServerStorageDatasource mempoolServerStorageDatasource,
  }) : _datasource = mempoolServerStorageDatasource;

  @override
  Future<Result<void, MempoolFailure>> save(MempoolServer server) async {
    try {
      final model = MempoolServerModel.fromEntity(server);
      await _datasource.store(model);
      return const Ok(null);
    } catch (e, st) {
      log.severe(message: 'Failed to save mempool server', error: e, trace: st);
      return Err(MempoolSaveFailure(e.toString()));
    }
  }

  @override
  Future<Result<MempoolServer?, MempoolFailure>> fetchCustomServer(
    MempoolServerNetwork network,
  ) async {
    try {
      final model = await _datasource.fetchCustomServerByNetwork(network);
      return Ok(model?.toEntity());
    } catch (e, st) {
      log.severe(
        message: 'Failed to fetch custom mempool server',
        error: e,
        trace: st,
      );
      return Err(MempoolLoadFailure(e.toString()));
    }
  }

  @override
  Future<Result<MempoolServer, MempoolFailure>> fetchDefaultServer(
    MempoolServerNetwork network,
  ) async {
    try {
      final model = await _datasource.fetchDefaultServerByNetwork(network);
      if (model == null) {
        return const Err(MempoolLoadFailure('No default mempool server found'));
      }
      return Ok(model.toEntity());
    } catch (e, st) {
      log.severe(
        message: 'Failed to fetch default mempool server',
        error: e,
        trace: st,
      );
      return Err(MempoolLoadFailure(e.toString()));
    }
  }

  @override
  Future<Result<void, MempoolFailure>> deleteCustomServer(
    MempoolServerNetwork network,
  ) async {
    try {
      final deleted = await _datasource.deleteCustomServer(network);
      if (!deleted) return const Err(MempoolDeleteFailure('No row deleted'));
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to delete custom mempool server',
        error: e,
        trace: st,
      );
      return Err(MempoolDeleteFailure(e.toString()));
    }
  }
}
