import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/send/domain/domain_errors.dart';

/// Returns the discounted vsize of a Liquid PSET in vbytes.
///
/// Used when the UI needs to convert a user-typed absolute fee back to a
/// rate before handing it to LWK (which only accepts rates). Computing the
/// vsize requires a real PSET, so callers must build one first — typically
/// the same dummy/drain PSET used to populate the absolute fee preview.
class CalculateLiquidPsetSizeUsecase {
  final LiquidWalletRepository _liquidWalletRepository;

  CalculateLiquidPsetSizeUsecase({
    required LiquidWalletRepository liquidWalletRepository,
  }) : _liquidWalletRepository = liquidWalletRepository;

  Future<int> execute({required String pset}) async {
    try {
      final (discountedVsize, _) =
          await _liquidWalletRepository.getPsetSizeAndAbsoluteFees(pset: pset);
      return discountedVsize;
    } catch (e) {
      throw CalculateLiquidPsetSizeException(e.toString());
    }
  }
}
