import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/domain/ports/electrum_server_port.dart';
import 'package:bb_mobile/core/electrum/domain/electrum_fallback_runner.dart';

class BitcoinBlockchainRepository {
  final BdkBitcoinBlockchainDatasource _blockchain;

  const BitcoinBlockchainRepository({
    required BdkBitcoinBlockchainDatasource blockchainDatasource,
  }) : _blockchain = blockchainDatasource;

  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required List<ElectrumServer> electrumServers,
  }) {
    return runElectrumFallback<ElectrumServer, String>(
      servers: electrumServers,
      urlOf: (server) => server.url,
      isCustomOf: (server) => server.isCustom,
      operation: (server) =>
          _blockchain.broadcastPsbt(finalizedPsbt, electrumServer: server),
    );
  }

  Future<String> broadcastTransaction(
    List<int> transaction, {
    required List<ElectrumServer> electrumServers,
  }) {
    return runElectrumFallback<ElectrumServer, String>(
      servers: electrumServers,
      urlOf: (server) => server.url,
      isCustomOf: (server) => server.isCustom,
      operation: (server) => _blockchain.broadcastTransaction(
        Uint8List.fromList(transaction),
        electrumServer: server,
      ),
    );
  }
}
