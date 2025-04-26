import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_wallet_repository.dart';

class CalculateBitcoinAbsoluteFeesUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;

  CalculateBitcoinAbsoluteFeesUsecase({
    required BitcoinWalletRepository bitcoinWalletRepository,
  }) : _bitcoinWalletRepository = bitcoinWalletRepository;

  /// Returns (amount, absFees)
  Future<int> execute({
    required String psbt,
    required double feeRate,
  }) async {
    try {
      final size = await _bitcoinWalletRepository.getTxSize(psbt: psbt);
      final absFees = (size * feeRate).toInt();
      return absFees;
    } catch (e) {
      throw CalculateBitcoinAbsoluteFeesException(e.toString());
    }
  }
}

class CalculateBitcoinAbsoluteFeesException implements Exception {
  final String message;

  CalculateBitcoinAbsoluteFeesException(this.message);
}
