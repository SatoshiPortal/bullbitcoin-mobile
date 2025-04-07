import 'dart:typed_data';

import 'package:lwk/lwk.dart' as lwk;

class LwkLiquidBlockchainDatasource {
  const LwkLiquidBlockchainDatasource();

  Future<String> broadcastTransaction(
    Uint8List transaction, {
    required String electrumServerUrl,
  }) async {
    final txId = await lwk.Wallet.broadcastTx(
      electrumUrl: electrumServerUrl,
      txBytes: transaction,
    );
    return txId;
  }
}
