import 'package:bb_mobile/core/wallet/domain/repositories/liquid_wallet_repository.dart';

class CalculateLiquidAbsoluteFeesUsecase {
  final LiquidWalletRepository _liquidWalletRepository;

  CalculateLiquidAbsoluteFeesUsecase({
    required LiquidWalletRepository liquidWalletRepository,
  }) : _liquidWalletRepository = liquidWalletRepository;

  /// Returns (amount, absFees)
  Future<int> execute({
    required String walletId,
    required String pset,
  }) async {
    try {
      final (amount, absFees) =
          await _liquidWalletRepository.getPsetAmountAndFees(
        walletId: walletId,
        pset: pset,
      );
      return absFees;
    } catch (e) {
      throw CalculateLiquidAbsoluteFeesException(e.toString());
    }
  }
}

class CalculateLiquidAbsoluteFeesException implements Exception {
  final String message;

  CalculateLiquidAbsoluteFeesException(this.message);
}
