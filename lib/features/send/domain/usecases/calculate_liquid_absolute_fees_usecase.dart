import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';

class CalculateLiquidAbsoluteFeesUsecase {
  final LiquidWalletRepository _liquidWalletRepository;

  CalculateLiquidAbsoluteFeesUsecase({
    required LiquidWalletRepository liquidWalletRepository,
  }) : _liquidWalletRepository = liquidWalletRepository;

  /// Returns (size, absFees)
  Future<int> execute({required String pset}) async {
    try {
      final (discountedVsize, absFees) = await _liquidWalletRepository
          .getPsetSizeAndAbsoluteFees(pset: pset);
      return absFees;
    } catch (e) {
      throw CalculateLiquidAbsoluteFeesException(e.toString());
    }
  }
}

class CalculateLiquidAbsoluteFeesException extends BullException {
  CalculateLiquidAbsoluteFeesException(super.message);
}
