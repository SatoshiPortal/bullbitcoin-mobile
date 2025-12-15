import 'dart:typed_data';

import 'package:bb_mobile/core_deprecated/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core_deprecated/blockchain/domain/ports/electrum_server_port.dart';

class BitcoinBlockchainRepository {
  final BdkBitcoinBlockchainDatasource _blockchain;

  const BitcoinBlockchainRepository({
    required BdkBitcoinBlockchainDatasource blockchainDatasource,
  }) : _blockchain = blockchainDatasource;

  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required List<ElectrumServer> electrumServers,
  }) async {
    for (int i = 0; i < electrumServers.length; i++) {
      final electrumServer = electrumServers[i];

      try {
        final txId = await _blockchain.broadcastPsbt(
          finalizedPsbt,
          electrumServer: electrumServer,
        );
        return txId;
      } catch (e) {
        // If broadcasting fails, try the next server
        continue;
      }
    }

    throw Exception('Failed to broadcast PSBT on all Electrum servers.');
  }

  Future<String> broadcastTransaction(
    List<int> transaction, {
    required List<ElectrumServer> electrumServers,
  }) async {
    for (int i = 0; i < electrumServers.length; i++) {
      final electrumServer = electrumServers[i];

      try {
        final txId = await _blockchain.broadcastTransaction(
          Uint8List.fromList(transaction),
          electrumServer: electrumServer,
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
