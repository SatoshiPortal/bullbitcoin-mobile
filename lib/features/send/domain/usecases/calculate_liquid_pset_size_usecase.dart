import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Returns the discounted vsize of a Liquid PSET in vbytes.
///
/// Used when the UI needs to convert a user-typed absolute fee back to a
/// rate before handing it to LWK (which only accepts rates). Computing the
/// vsize requires a real PSET, so callers must build one first — typically
/// the same dummy/drain PSET used to populate the absolute fee preview.
class CalculateLiquidPsetSizeUsecase {
  final LiquidWalletRepository _liquidWalletRepository;

  CalculateLiquidPsetSizeUsecase({required this._liquidWalletRepository});

  @useResult
  Future<Result<int, SendFailure>> execute({required String pset}) async {
    try {
      final (discountedVsize, _) = await _liquidWalletRepository
          .getPsetSizeAndAbsoluteFees(pset: pset);
      return Ok(discountedVsize);
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the discounted vsize of a Liquid PSET',
        error: e,
        trace: st,
      );
      return Err(SendTransactionBuildFailure(e.toString()));
    }
  }
}
