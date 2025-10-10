import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_server_model.dart';

class DriftElectrumServerRepository implements ElectrumServerRepository {
  final ElectrumServerStorageDatasource _datasource;

  DriftElectrumServerRepository({
    required ElectrumServerStorageDatasource electrumServerStorageDatasource,
  }) : _datasource = electrumServerStorageDatasource;

  @override
  Future<void> save(ElectrumServer server) {
    final model = ElectrumServerModel.fromEntity(server);
    return _datasource.store(model);
  }

  @override
  Future<void> batchSave(List<ElectrumServer> servers) {
    final models =
        servers.map((e) => ElectrumServerModel.fromEntity(e)).toList();
    return _datasource.storeBatch(models);
  }

  @override
  Future<List<ElectrumServer>> fetchAll({
    bool? isTestnet,
    bool? isLiquid,
    bool? isCustom,
  }) {
    return _datasource
        .fetchAllServers(
          isTestnet: isTestnet,
          isLiquid: isLiquid,
          isCustom: isCustom,
        )
        .then((models) => models.map((e) => e.toEntity()).toList());
  }

  @override
  Future<List<ElectrumServer>> fetchCustomServers({
    required ElectrumServerNetwork network,
  }) {
    return _datasource
        .fetchCustomServersByNetwork(network)
        .then((models) => models.map((e) => e.toEntity()).toList());
  }

  @override
  Future<List<ElectrumServer>> fetchDefaultServers({
    required ElectrumServerNetwork network,
  }) {
    return _datasource
        .fetchDefaultServersByNetwork(network)
        .then((models) => models.map((e) => e.toEntity()).toList());
  }

  @override
  Future<void> delete({required String url}) {
    return _datasource.deleteServer(url);
  }
}
