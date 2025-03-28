

import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_datasource.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

class ElectrumServerRepositoryImpl implements ElectrumServerRepository {
  final ElectrumServerDatasource _electrumServerDatasource;

  const ElectrumServerRepositoryImpl({
    required ElectrumServerDatasource electrumServerDatasource,
  }) : _electrumServerDatasource = electrumServerDatasource;

  @override
  Future<ElectrumServer> getElectrumServer({required Network network}) async {
    final model = await _electrumServerDatasource.get(
      network: network,
    );
    if (model == null) {
      return ElectrumServer.publicFromNetwork(
        network: network,
      );
    }

    return model.toEntity();
  }

  @override
  Future<void> setElectrumServer(ElectrumServer server) async {
    final network = server.network;
    final model = ElectrumServerModel(
      url: server.url,
      socks5: server.socks5,
      retry: server.retry,
      timeout: server.timeout,
      stopGap: server.stopGap,
      validateDomain: server.validateDomain,
      isTestnet: network.isTestnet,
      isLiquid: network.isLiquid,
    );

    await _electrumServerDatasource.set(
      model,
      network: network,
    );
  }
}
