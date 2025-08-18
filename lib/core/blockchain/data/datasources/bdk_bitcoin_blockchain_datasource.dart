import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class BdkBitcoinBlockchainDatasource {
  const BdkBitcoinBlockchainDatasource();

  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required ElectrumServerModel electrumServer,
  }) async {
    final blockchain = await createBlockchainFromElectrumServer(electrumServer);
    final psbt = await bdk.PartiallySignedTransaction.fromString(finalizedPsbt);
    final tx = psbt.extractTx();
    final txId = await blockchain.broadcast(transaction: tx);
    return txId;
  }

  Future<String> broadcastTransaction(
    Uint8List transaction, {
    required ElectrumServerModel electrumServer,
  }) async {
    final blockchain = await createBlockchainFromElectrumServer(electrumServer);
    final tx = await bdk.Transaction.fromBytes(transactionBytes: transaction);
    final txId = await blockchain.broadcast(transaction: tx);
    return txId;
  }

  static Future<bdk.Blockchain> createBlockchainFromElectrumServer(
    ElectrumServerModel electrumServer,
  ) async {
    final blockchain = await bdk.Blockchain.create(
      config: bdk.BlockchainConfig.electrum(
        config: bdk.ElectrumConfig(
          url: electrumServer.url,
          socks5: electrumServer.socks5,
          retry: electrumServer.retry,
          timeout: electrumServer.timeout,
          stopGap: BigInt.from(electrumServer.stopGap),
          validateDomain: electrumServer.validateDomain,
        ),
      ),
    );

    return blockchain;
  }
}
