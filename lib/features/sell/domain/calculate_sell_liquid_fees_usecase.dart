import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The absolute fee, in sats, that LWK reports for a sell payin PSET.
class CalculateSellLiquidFeesUsecase {
  final LiquidWalletRepository _liquidWalletRepository;

  const CalculateSellLiquidFeesUsecase({required this._liquidWalletRepository});

  @useResult
  Future<Result<int, SellFailure>> execute({required String pset}) async {
    try {
      final (_, absoluteFees) = await _liquidWalletRepository
          .getPsetSizeAndAbsoluteFees(pset: pset);
      return Ok(absoluteFees);
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the absolute fees of a sell payin PSET',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
    }
  }
}
