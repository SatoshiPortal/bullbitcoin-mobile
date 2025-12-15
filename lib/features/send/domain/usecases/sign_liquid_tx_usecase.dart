import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/repositories/liquid_wallet_repository.dart';

class SignLiquidTxUsecase {
  final LiquidWalletRepository _liquidWalletRepository;

  SignLiquidTxUsecase({required LiquidWalletRepository liquidWalletRepository})
    : _liquidWalletRepository = liquidWalletRepository;

  Future<String> execute({
    required String pset,
    required String walletId,
  }) async {
    try {
      final signedPset = await _liquidWalletRepository.signPset(
        pset: pset,
        walletId: walletId,
      );

      return signedPset;
    } catch (e) {
      throw SignLiquidTxException(e.toString());
    }
  }
}

class SignLiquidTxException extends BullException {
  SignLiquidTxException(super.message);
}
