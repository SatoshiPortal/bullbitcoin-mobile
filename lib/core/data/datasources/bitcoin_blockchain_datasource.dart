import 'package:bb_mobile/core/data/models/electrum_server_model.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class BitcoinBlockchainDatasource {
  final bdk.Blockchain _blockchain;

  BitcoinBlockchainDatasource({required bdk.Blockchain blockchain})
      : _blockchain = blockchain;

  static Future<BitcoinBlockchainDatasource> fromElectrumServer(
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

    return BitcoinBlockchainDatasource(blockchain: blockchain);
  }

  Future<String> broadcastPsbt(String finalizedPsbt) async {
    final psbt = await bdk.PartiallySignedTransaction.fromString(finalizedPsbt);
    final tx = psbt.extractTx();
    final txId = await _blockchain.broadcast(transaction: tx);
    return txId;
  }
}
