import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_server_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_server_model.dart';

class DriftMempoolServerRepository implements MempoolServerRepository {
  final MempoolServerStorageDatasource _datasource;

  DriftMempoolServerRepository({
    required MempoolServerStorageDatasource mempoolServerStorageDatasource,
  }) : _datasource = mempoolServerStorageDatasource;

  @override
  Future<void> save(MempoolServer server) {
    final model = MempoolServerModel.fromEntity(server);
    return _datasource.store(model);
  }

  @override
  Future<MempoolServer?> fetchCustomServer(MempoolServerNetwork network) async {
    final model = await _datasource.fetchCustomServerByNetwork(network);
    return model?.toEntity();
  }

  @override
  Future<MempoolServer> fetchDefaultServer(MempoolServerNetwork network) async {
    final model = await _datasource.fetchDefaultServerByNetwork(network);
    if (model == null) {
      throw Exception('No default mempool server found for network: $network');
    }
    return model.toEntity();
  }

  @override
  Future<void> deleteCustomServer(MempoolServerNetwork network) {
    return _datasource.deleteCustomServer(network);
  }
}
