import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

class BdkBitcoinBlockchainDatasource {
  const BdkBitcoinBlockchainDatasource();

  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required ElectrumConnection connection,
  }) async {
    final blockchain = await _createClient(connection);
    final psbt = bdk.Psbt(psbtBase64: finalizedPsbt);
    final tx = psbt.extractTx();
    final txId = blockchain.transactionBroadcast(tx: tx);
    return txId.toString();
  }

  Future<String> broadcastTransaction(
    Uint8List transaction, {
    required ElectrumConnection connection,
  }) async {
    final blockchain = await _createClient(connection);
    final tx = bdk.Transaction(transactionBytes: transaction);
    final txId = blockchain.transactionBroadcast(tx: tx);
    return txId.toString();
  }

  static Future<bdk.ElectrumClient> _createClient(
    ElectrumConnection connection,
  ) async {
    return bdk.ElectrumClient(
      url: connection.url,
      socks5: connection.socks5?.isNotEmpty == true ? connection.socks5 : null,
      // electrum-client caps timeout/retry at u8 (255s, 255 retries).
      timeout: connection.timeout.clamp(0, 255),
      retry: connection.retry.clamp(0, 255),
      validateDomain: connection.validateDomain,
    );
  }
}
