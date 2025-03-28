import 'package:bb_mobile/core/bitcoin/data/datasources/bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/bitcoin/domain/repositories/bitcoin_blockchain_repository.dart';

import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';

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
    final blockchain = await BitcoinBlockchainDatasource.fromElectrumServer(
      electrumServerModel,
    );

    return blockchain.broadcastPsbt(finalizedPsbt);
  }
}
