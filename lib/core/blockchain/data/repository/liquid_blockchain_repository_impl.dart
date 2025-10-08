import 'package:bb_mobile/core/blockchain/data/datasources/lwk_liquid_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/domain/electrum_server.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';

class LiquidBlockchainRepositoryImpl implements LiquidBlockchainRepository {
  final LwkLiquidBlockchainDatasource _blockchain;

  const LiquidBlockchainRepositoryImpl({
    required LwkLiquidBlockchainDatasource blockchainDatasource,
  }) : _blockchain = blockchainDatasource;

  @override
  Future<String> broadcastTransaction({
    required String signedPset,
    required List<ElectrumServer> electrumServers,
  }) async {
    for (int i = 0; i < electrumServers.length; i++) {
      final electrumServer = electrumServers[i];

      try {
        final txId = await _blockchain.broadcastTransaction(
          signedPset: signedPset,
          electrumServerUrl: electrumServer.url,
        );
        return txId;
      } catch (e) {
        // If broadcasting fails, try the next server
        continue;
      }
    }

    throw Exception('Failed to broadcast transaction on all Electrum servers.');
  }
}
