import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';

class BroadcastLiquidUsecase {
  final LiquidBlockchainRepository _liquidBlockchainRepository;

  BroadcastLiquidUsecase({
    required LiquidBlockchainRepository liquidBlockchainRepository,
  }) : _liquidBlockchainRepository = liquidBlockchainRepository;

  Future<String> execute({
    required String signedPset,
    required bool isTestnet,
  }) async {
    try {
      return await _liquidBlockchainRepository.broadcastTransaction(
        signedPset: signedPset,
        isTestnet: isTestnet,
      );
    } catch (e) {
      throw BroadcastLiquidException(e.toString());
    }
  }
}

class BroadcastLiquidException implements Exception {
  final String message;

  BroadcastLiquidException(this.message);
}
