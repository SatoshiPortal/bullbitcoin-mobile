import 'dart:typed_data';

import 'package:lwk/lwk.dart' as lwk;

abstract class LiquidBlockchainDatasource {
  Future<String> broadcastTransaction(
    Uint8List transaction, {
    required String electrumServerUrl,
  });
}

class LwkLiquidBlockchainDatasource implements LiquidBlockchainDatasource {
  const LwkLiquidBlockchainDatasource();

  @override
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
