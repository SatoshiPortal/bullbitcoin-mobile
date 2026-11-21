import 'package:mempool/src/domain/entities/mempool_server.dart';
import 'package:mempool/src/domain/mempool_failure.dart';
import 'package:mempool/src/domain/repositories/mempool_server_repository.dart';
import 'package:mempool/src/domain/value_objects/mempool_server_network.dart';
import 'package:mempool/src/data/mempool_dao.dart';
import 'package:mempool/src/data/models/mempool_server_model.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

class DriftMempoolServerRepository implements MempoolServerRepository {
  final MempoolDao _datasource;

  DriftMempoolServerRepository({
    required MempoolDao mempoolServerStorageDatasource,
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
      return Err(MempoolLoadFailure(MempoolServerKind.custom, e.toString()));
    }
  }

  @override
  Future<Result<MempoolServer, MempoolFailure>> fetchDefaultServer(
    MempoolServerNetwork network,
  ) async {
    try {
      final model = await _datasource.fetchDefaultServerByNetwork(network);
      if (model == null) {
        return const Err(
          MempoolLoadFailure(
            MempoolServerKind.defaultServer,
            'No default mempool server found',
          ),
        );
      }
      return Ok(model.toEntity());
    } catch (e, st) {
      log.severe(
        message: 'Failed to fetch default mempool server',
        error: e,
        trace: st,
      );
      return Err(
        MempoolLoadFailure(MempoolServerKind.defaultServer, e.toString()),
      );
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
