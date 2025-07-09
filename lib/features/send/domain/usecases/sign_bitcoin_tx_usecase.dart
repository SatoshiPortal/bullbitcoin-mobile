import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';

class SignBitcoinTxUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;

  SignBitcoinTxUsecase({
    required BitcoinWalletRepository bitcoinWalletRepository,
  }) : _bitcoinWalletRepository = bitcoinWalletRepository;
  Future<({String signedPsbt, int txSize})> execute({
    required String psbt,
    required String walletId,
  }) async {
    try {
      final signedPsbt = await _bitcoinWalletRepository.signPsbt(
        psbt,
        walletId: walletId,
      );
      final size = await _bitcoinWalletRepository.getTxSize(psbt: signedPsbt);
      return (signedPsbt: signedPsbt, txSize: size);
    } catch (e) {
      throw SignBitcoinTxException(e.toString());
    }
  }
}

class SignBitcoinTxException implements Exception {
  final String message;

  SignBitcoinTxException(this.message);
}
