import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/lwk_liquid_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

class LiquidBlockchainRepositoryImpl implements LiquidBlockchainRepository {
  final LiquidBlockchainDatasource _blockchain;
  final ElectrumServerDatasource _electrumServer;

  const LiquidBlockchainRepositoryImpl({
    required LiquidBlockchainDatasource blockchainDatasource,
    required ElectrumServerDatasource electrumServerDatasource,
  })  : _blockchain = blockchainDatasource,
        _electrumServer = electrumServerDatasource;

  @override
  Future<String> broadcastTransaction(
    Uint8List transaction, {
    required Network network,
  }) async {
    final electrumServerModel = await _electrumServer.get(network: network);

    if (electrumServerModel == null) {
      throw Exception('No electrum server found for network: $network');
    }

    return _blockchain.broadcastTransaction(
      transaction,
      electrumServerUrl: electrumServerModel.url,
    );
  }
}
