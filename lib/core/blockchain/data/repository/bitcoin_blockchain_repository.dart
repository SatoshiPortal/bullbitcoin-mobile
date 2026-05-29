import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

/// Thin repository over [BdkBitcoinBlockchainDatasource]. Its only job is to
/// route broadcast operations through [ElectrumServersPort.runWithFallback]
/// so callers cannot fetch a server list themselves — the privacy / fallback
/// rule lives in one place.
class BitcoinBlockchainRepository {
  final BdkBitcoinBlockchainDatasource _blockchain;
  final ElectrumServersPort _serversPort;

  const BitcoinBlockchainRepository({
    required BdkBitcoinBlockchainDatasource blockchainDatasource,
    required ElectrumServersPort serversPort,
  }) : _blockchain = blockchainDatasource,
       _serversPort = serversPort;

  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required bool isTestnet,
  }) {
    return _serversPort.runWithFallback<String>(
      network: ElectrumServerNetwork.fromEnvironment(
        isTestnet: isTestnet,
        isLiquid: false,
      ),
      operation: (connection) =>
          _blockchain.broadcastPsbt(finalizedPsbt, connection: connection),
    );
  }

  Future<String> broadcastTransaction(
    List<int> transaction, {
    required bool isTestnet,
  }) {
    return _serversPort.runWithFallback<String>(
      network: ElectrumServerNetwork.fromEnvironment(
        isTestnet: isTestnet,
        isLiquid: false,
      ),
      operation: (connection) => _blockchain.broadcastTransaction(
        Uint8List.fromList(transaction),
        connection: connection,
      ),
    );
  }
}
