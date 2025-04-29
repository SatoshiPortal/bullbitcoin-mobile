import 'package:bb_mobile/core/wallet/domain/repositories/liquid_wallet_repository.dart';

class SignLiquidTxUsecase {
  final LiquidWalletRepository _liquidWalletRepository;

  SignLiquidTxUsecase({required LiquidWalletRepository liquidWalletRepository})
    : _liquidWalletRepository = liquidWalletRepository;

  Future<String> execute({
    required String psbt,
    required String walletId,
  }) async {
    try {
      final signedPset = await _liquidWalletRepository.signPset(
        pset: psbt,
        walletId: walletId,
      );

      return signedPset;
    } catch (e) {
      throw SignLiquidTxException(e.toString());
    }
  }
}

class SignLiquidTxException implements Exception {
  final String message;

  SignLiquidTxException(this.message);
}
