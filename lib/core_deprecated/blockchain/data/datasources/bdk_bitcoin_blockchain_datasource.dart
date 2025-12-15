import 'dart:typed_data';

import 'package:bb_mobile/core_deprecated/blockchain/domain/ports/electrum_server_port.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class BdkBitcoinBlockchainDatasource {
  const BdkBitcoinBlockchainDatasource();

  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required ElectrumServer electrumServer,
  }) async {
    final blockchain = await createBlockchainFromElectrumServer(electrumServer);
    final psbt = await bdk.PartiallySignedTransaction.fromString(finalizedPsbt);
    final tx = psbt.extractTx();
    final txId = await blockchain.broadcast(transaction: tx);
    return txId;
  }

  Future<String> broadcastTransaction(
    Uint8List transaction, {
    required ElectrumServer electrumServer,
  }) async {
    final blockchain = await createBlockchainFromElectrumServer(electrumServer);
    final tx = await bdk.Transaction.fromBytes(transactionBytes: transaction);
    final txId = await blockchain.broadcast(transaction: tx);
    return txId;
  }

  static Future<bdk.Blockchain> createBlockchainFromElectrumServer(
    ElectrumServer electrumServer,
  ) async {
    final blockchain = await bdk.Blockchain.create(
      config: bdk.BlockchainConfig.electrum(
        config: bdk.ElectrumConfig(
          url: electrumServer.url,
          // Only set the socks5 if it's not empty,
          //  otherwise bdk will throw an error
          socks5:
              electrumServer.socks5?.isNotEmpty == true
                  ? electrumServer.socks5
                  : null,
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
