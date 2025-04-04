import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

class BitcoinBlockchainRepositoryImpl implements BitcoinBlockchainRepository {
  final BitcoinBlockchainDatasource _blockchain;
  final ElectrumServerStorageDatasource _electrumServerStorage;

  const BitcoinBlockchainRepositoryImpl({
    required BitcoinBlockchainDatasource blockchainDatasource,
    required ElectrumServerStorageDatasource electrumServerStorageDatasource,
  })  : _blockchain = blockchainDatasource,
        _electrumServerStorage = electrumServerStorageDatasource;

  @override
  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required bool isTestnet,
  }) async {
    // Todo: Should we first try the custom and only if it fails or doesn't exist
    // try the default bullbitcoin and blockstream servers?
    final electrumServerModel = await _electrumServerStorage.getByProvider(
          ElectrumServerProvider.blockstream,
          network: Network.fromEnvironment(
            isTestnet: isTestnet,
            isLiquid: false,
          ),
        ) ??
        ElectrumServerModel.blockstream(
          isTestnet: isTestnet,
          isLiquid: false,
        );

    return _blockchain.broadcastPsbt(
      finalizedPsbt,
      electrumServer: electrumServerModel,
    );
  }
}
