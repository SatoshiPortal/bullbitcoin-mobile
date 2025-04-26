import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_wallet_repository.dart';

class SignBitcoinTxUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;

  SignBitcoinTxUsecase({
    required BitcoinWalletRepository bitcoinWalletRepository,
  }) : _bitcoinWalletRepository = bitcoinWalletRepository;
  Future<String> execute({
    required String psbt,
    required String walletId,
  }) async {
    try {
      return await _bitcoinWalletRepository.signPsbt(
        psbt,
        walletId: walletId,
      );
    } catch (e) {
      throw SignBitcoinTxException(e.toString());
    }
  }
}

class SignBitcoinTxException implements Exception {
  final String message;

  SignBitcoinTxException(this.message);
}
