import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/liquid_wallet_repository.dart';

class ConfirmLiquidSendUsecase {
  final LiquidWalletRepository _liquidWalletRepository;
  final LiquidBlockchainRepository _liquidBlockchainRepository;

  ConfirmLiquidSendUsecase({
    required LiquidWalletRepository liquidWalletRepository,
    required LiquidBlockchainRepository liquidBlockchainRepository,
  })  : _liquidWalletRepository = liquidWalletRepository,
        _liquidBlockchainRepository = liquidBlockchainRepository;

  Future<String> execute({
    required String psbt,
    required String walletId,
    required bool isTestnet,
  }) async {
    try {
      // Get the wallet by ID

      final signedPsbt = await _liquidWalletRepository.signPset(
        psbt,
        walletId: walletId,
      );

      final txId = await _liquidBlockchainRepository.broadcastTransaction(
        signedPsbt,
        isTestnet: isTestnet,
      );

      return txId;
    } catch (e) {
      throw ConfirmBitcoinSendException(e.toString());
    }
  }
}

class ConfirmBitcoinSendException implements Exception {
  final String message;

  ConfirmBitcoinSendException(this.message);
}
