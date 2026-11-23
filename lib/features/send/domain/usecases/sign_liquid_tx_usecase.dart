import 'package:primitives/legacy_exceptions.dart';
import 'package:bb_mobile/features/send/data/liquid_wallet_repository.dart';

class SignLiquidTxUsecase {
  final LiquidWalletRepository _liquidWalletRepository;

  SignLiquidTxUsecase({required this._liquidWalletRepository});

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
