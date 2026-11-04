import 'package:primitives/primitives.dart';
import 'package:wallet/wallet.dart';

class CalculateBitcoinAbsoluteFeesUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;

  CalculateBitcoinAbsoluteFeesUsecase({required this._bitcoinWalletRepository});

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
