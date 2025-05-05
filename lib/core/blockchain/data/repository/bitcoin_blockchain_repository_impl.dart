import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart'
    show DefaultElectrumServerProvider;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class BitcoinBlockchainRepositoryImpl implements BitcoinBlockchainRepository {
  final BdkBitcoinBlockchainDatasource _blockchain;
  final ElectrumServerStorageDatasource _electrumServerStorage;

  const BitcoinBlockchainRepositoryImpl({
    required BdkBitcoinBlockchainDatasource blockchainDatasource,
    required ElectrumServerStorageDatasource electrumServerStorageDatasource,
  }) : _blockchain = blockchainDatasource,
       _electrumServerStorage = electrumServerStorageDatasource;

  @override
  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required bool isTestnet,
  }) async {
    // Todo: Should we first try the custom and only if it fails or doesn't exist
    // try the default bullbitcoin and blockstream servers?
    final electrumServerModel =
        await _electrumServerStorage.fetchDefaultServerByProvider(
          DefaultElectrumServerProvider.bullBitcoin,
          network: Network.fromEnvironment(
            isTestnet: isTestnet,
            isLiquid: false,
          ),
        ) ??
        ElectrumServerModel.defaultServer(
          isTestnet: isTestnet,
          isLiquid: false,
          defaultElectrumServerProvider:
              DefaultElectrumServerProvider.bullBitcoin,
        );

    return _blockchain.broadcastPsbt(
      finalizedPsbt,
      electrumServer: electrumServerModel,
    );
  }
}
