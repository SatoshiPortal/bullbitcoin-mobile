import 'package:bb_mobile/core/blockchain/domain/repositories/bitcoin_blockchain_repository.dart';

class BroadcastBitcoinUsecase {
  final BitcoinBlockchainRepository _bitcoinBlockchainRepository;

  BroadcastBitcoinUsecase({
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
  }) : _bitcoinBlockchainRepository = bitcoinBlockchainRepository;

  Future<String> execute({
    required String finalizedPsbt,
    required bool isTestnet,
  }) async {
    try {
      return await _bitcoinBlockchainRepository.broadcastPsbt(
        finalizedPsbt,
        isTestnet: isTestnet,
      );
    } catch (e) {
      throw BroadcastBitcoinException(e.toString());
    }
  }
}

class BroadcastBitcoinException implements Exception {
  final String message;

  BroadcastBitcoinException(this.message);
}
