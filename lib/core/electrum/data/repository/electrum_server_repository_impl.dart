import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

class ElectrumServerRepositoryImpl implements ElectrumServerRepository {
  final ElectrumServerStorageDatasource _electrumServerStorage;

  const ElectrumServerRepositoryImpl({
    required ElectrumServerStorageDatasource electrumServerStorageDatasource,
  }) : _electrumServerStorage = electrumServerStorageDatasource;

  @override
  Future<void> setElectrumServer(ElectrumServer server) async {
    final model = ElectrumServerModel.fromEntity(server);

    await _electrumServerStorage.set(model);
  }

  @override
  Future<ElectrumServer> getElectrumServer({
    required ElectrumServerProvider provider,
    required Network network,
  }) async {
    ElectrumServerModel? model = await _electrumServerStorage.getByProvider(
      provider,
      network: network,
    );

    if (model == null) {
      switch (provider) {
        case ElectrumServerProvider.bullBitcoin:
          model = ElectrumServerModel.bullBitcoin(
            isTestnet: network.isTestnet,
            isLiquid: network.isLiquid,
          );
        case ElectrumServerProvider.blockstream:
          model = ElectrumServerModel.blockstream(
            isTestnet: network.isTestnet,
            isLiquid: network.isLiquid,
          );
        case ElectrumServerProvider.custom:
          throw Exception('Custom electrum server not found');
      }
    }

    return model.toEntity();
  }

  @override
  Future<List<ElectrumServer>> getElectrumServers({
    required Network network,
  }) async {
    final custom = await _electrumServerStorage.getByProvider(
      ElectrumServerProvider.custom,
      network: network,
    );

    final blockstream = await _electrumServerStorage.getByProvider(
          ElectrumServerProvider.blockstream,
          network: network,
        ) ??
        ElectrumServerModel.blockstream(
          isTestnet: network.isTestnet,
          isLiquid: network.isLiquid,
        );

    final bullBitcoin = await _electrumServerStorage.getByProvider(
          ElectrumServerProvider.bullBitcoin,
          network: network,
        ) ??
        ElectrumServerModel.bullBitcoin(
          isTestnet: network.isTestnet,
          isLiquid: network.isLiquid,
        );

    return [
      if (custom != null) custom.toEntity(),
      blockstream.toEntity(),
      bullBitcoin.toEntity(),
    ];
  }
}
