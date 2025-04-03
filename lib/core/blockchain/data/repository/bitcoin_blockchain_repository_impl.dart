import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

class BitcoinBlockchainRepositoryImpl implements BitcoinBlockchainRepository {
  final BitcoinBlockchainDatasource _blockchain;
  final ElectrumServerDatasource _electrumServer;

  const BitcoinBlockchainRepositoryImpl({
    required BitcoinBlockchainDatasource blockchainDatasource,
    required ElectrumServerDatasource electrumServerDatasource,
  })  : _blockchain = blockchainDatasource,
        _electrumServer = electrumServerDatasource;

  @override
  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required Network network,
  }) async {
    final electrumServerModel = await _electrumServer.get(network: network);

    if (electrumServerModel == null) {
      throw Exception('No electrum server found for network: $network');
    }

    return _blockchain.broadcastPsbt(
      finalizedPsbt,
      electrumServer: electrumServerModel,
    );
  }
}
