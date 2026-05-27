import 'package:bb_mobile/core/blockchain/data/datasources/lwk_liquid_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/domain/ports/electrum_server_port.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/electrum/domain/electrum_fallback_runner.dart';

class LiquidBlockchainRepositoryImpl implements LiquidBlockchainRepository {
  final LwkLiquidBlockchainDatasource _blockchain;

  const LiquidBlockchainRepositoryImpl({
    required LwkLiquidBlockchainDatasource blockchainDatasource,
  }) : _blockchain = blockchainDatasource;

  @override
  Future<String> broadcastTransaction({
    required String signedPset,
    required List<ElectrumServer> electrumServers,
  }) {
    return runElectrumFallback<ElectrumServer, String>(
      servers: electrumServers,
      urlOf: (server) => server.url,
      isCustomOf: (server) => server.isCustom,
      operation: (server) => _blockchain.broadcastTransaction(
        signedPset: signedPset,
        electrumServerUrl: server.url,
      ),
    );
  }
}
