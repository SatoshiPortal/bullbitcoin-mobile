import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class BitcoinBlockchainRepository {
  final BdkBitcoinBlockchainDatasource _blockchain;
  final ElectrumServerStorageDatasource _electrumServerStorage;

  const BitcoinBlockchainRepository({
    required BdkBitcoinBlockchainDatasource blockchainDatasource,
    required ElectrumServerStorageDatasource electrumServerStorageDatasource,
  }) : _blockchain = blockchainDatasource,
       _electrumServerStorage = electrumServerStorageDatasource;

  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required bool isTestnet,
  }) async {
    // Todo: Should we first try the custom and only if it fails or doesn't exist
    // try the default bullbitcoin and blockstream servers?
    final electrumServerModel = await _electrumServerStorage
        .getDefaultServerByProvider(
          DefaultElectrumServerProvider.blockstream,
          network: Network.fromEnvironment(
            isTestnet: isTestnet,
            isLiquid: false,
          ),
        );

    // TODO(azad): this shouldn't be needed
    if (electrumServerModel == null) {
      throw 'blockstream should be in the database';
    }

    return _blockchain.broadcastPsbt(
      finalizedPsbt,
      electrumServer: electrumServerModel,
    );
  }
}
