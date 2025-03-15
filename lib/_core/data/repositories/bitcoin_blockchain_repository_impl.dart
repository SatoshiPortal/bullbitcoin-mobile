import 'package:bb_mobile/_core/data/datasources/bitcoin_blockchain_data_source.dart';
import 'package:bb_mobile/_core/data/models/electrum_server_model.dart';
import 'package:bb_mobile/_core/domain/entities/electrum_server.dart';
import 'package:bb_mobile/_core/domain/repositories/bitcoin_blockchain_repository.dart';

class BitcoinBlockchainRepositoryImpl implements BitcoinBlockchainRepository {
  const BitcoinBlockchainRepositoryImpl();

  @override
  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required ElectrumServer electrumServer,
  }) async {
    final electrumServerModel = ElectrumServerModel.fromEntity(electrumServer);

    // TODO: add both the blockchain data source as the repository as factories
    //  in the locator and then use the locator in use cases to create them
    //  instead of using a concrete implementation here
    final blockchain = await BdkBlockchainDataSourceImpl.fromElectrumServer(
      electrumServerModel,
    );

    return blockchain.broadcastPsbt(finalizedPsbt);
  }
}
