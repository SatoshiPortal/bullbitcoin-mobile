import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/domain/ports/electrum_server_port.dart';
import 'package:bdk_dart/bdk.dart' as bdk;

class BdkBitcoinBlockchainDatasource {
  const BdkBitcoinBlockchainDatasource();

  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required ElectrumServer electrumServer,
  }) async {
    final blockchain = await createBlockchainFromElectrumServer(electrumServer);
    final psbt = bdk.Psbt(psbtBase64: finalizedPsbt);
    final tx = psbt.extractTx();
    final txId = blockchain.transactionBroadcast(tx: tx);
    return txId.toString();
  }

  Future<String> broadcastTransaction(
    Uint8List transaction, {
    required ElectrumServer electrumServer,
  }) async {
    final blockchain = await createBlockchainFromElectrumServer(electrumServer);
    final tx = bdk.Transaction(transactionBytes: transaction);
    final txId = blockchain.transactionBroadcast(tx: tx);
    return txId.toString();
  }

  static Future<bdk.ElectrumClient> createBlockchainFromElectrumServer(
    ElectrumServer electrumServer,
  ) async {
    final blockchain = bdk.ElectrumClient(
      url: electrumServer.url,
      socks5: electrumServer.socks5?.isNotEmpty == true
          ? electrumServer.socks5
          : null,
      // electrum-client caps timeout/retry at u8 (255s, 255 retries).
      timeout: electrumServer.timeout.clamp(0, 255),
      retry: electrumServer.retry.clamp(0, 255),
      validateDomain: electrumServer.validateDomain,
    );

    return blockchain;
  }
}
