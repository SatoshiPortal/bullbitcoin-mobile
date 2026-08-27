import 'package:bb_mobile/core/blockchain/data/datasources/lwk_liquid_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class LiquidBlockchainRepositoryImpl implements LiquidBlockchainRepository {
  final LwkLiquidBlockchainDatasource _blockchain;
  final ElectrumServersPort _serversPort;

  const LiquidBlockchainRepositoryImpl({
    required LwkLiquidBlockchainDatasource blockchainDatasource,
    required this._serversPort,
  }) : _blockchain = blockchainDatasource;

  @override
  Future<String> broadcastTransaction({
    required String signedPset,
    required bool isTestnet,
  }) {
    return _serversPort.runWithFallback<String>(
      network: ElectrumServerNetwork.fromEnvironment(
        isTestnet: isTestnet,
        isLiquid: true,
      ),
      operation: (connection) => _blockchain.broadcastTransaction(
        signedPset: signedPset,
        electrumServerUrl: connection.url,
      ),
    );
  }
}
