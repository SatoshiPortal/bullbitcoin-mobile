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
      // Only set the socks5 if it's not empty,
      //  otherwise bdk will throw an error
      // TODO: this was in bdk_flutter, check if it's still needed in bdk_dart
      socks5: electrumServer.socks5?.isNotEmpty == true
          ? electrumServer.socks5
          : null,
    );

    return blockchain;
  }
}
