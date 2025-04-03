import 'package:bb_mobile/core/blockchain/domain/repositories/bitcoin_blockchain_repository.dart';

class BroadcastBitcoinTransactionUsecase {
  final BitcoinBlockchainRepository _bitcoinBlockchain;

  BroadcastBitcoinTransactionUsecase({
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
  }) : _bitcoinBlockchain = bitcoinBlockchainRepository;

  Future<String> execute(String psbt, {required bool isTestnet}) async {
    try {
      final txId = await _bitcoinBlockchain.broadcastPsbt(
        psbt,
        isTestnet: isTestnet,
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
