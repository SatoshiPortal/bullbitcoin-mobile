import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';

class CalculateBitcoinAbsoluteFeesUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;

  CalculateBitcoinAbsoluteFeesUsecase({
    required BitcoinWalletRepository bitcoinWalletRepository,
  }) : _bitcoinWalletRepository = bitcoinWalletRepository;

  /// Returns (amount, absFees)
  Future<int> execute({required String psbt}) async {
    try {
      final absFee = await _bitcoinWalletRepository.getTxFeeAmount(psbt: psbt);
      return absFee;
    } catch (e) {
      throw CalculateBitcoinAbsoluteFeesException(e.toString());
    }
  }
}

class CalculateBitcoinAbsoluteFeesException extends BullException {
  CalculateBitcoinAbsoluteFeesException(super.message);
}
