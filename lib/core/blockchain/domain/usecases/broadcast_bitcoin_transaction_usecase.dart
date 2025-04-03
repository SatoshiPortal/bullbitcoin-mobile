import 'package:bb_mobile/core/blockchain/domain/repositories/bitcoin_blockchain_repository.dart';

import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

class BroadcastBitcoinTransactionUsecase {
  final BitcoinBlockchainRepository _bitcoinBlockchain;

  BroadcastBitcoinTransactionUsecase({
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
  }) : _bitcoinBlockchain = bitcoinBlockchainRepository;

  Future<String> execute(String psbt, {required Network network}) async {
    try {
      final txId = await _bitcoinBlockchain.broadcastPsbt(
        psbt,
        network: network,
      );

      return txId;
    } catch (e) {
      throw FailedToBroadcastTransactionException(e.toString());
    }
  }
}

class FailedToBroadcastTransactionException implements Exception {
  final String message;

  FailedToBroadcastTransactionException(this.message);
}
