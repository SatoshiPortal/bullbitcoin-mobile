import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:meta/meta.dart';

/// Receive-owned boundary for the shared wallet use-case, which still throws.
class GetReceiveWalletsUsecase {
  final GetWalletsUsecase _getWalletsUsecase;

  const GetReceiveWalletsUsecase(this._getWalletsUsecase);

  @useResult
  Future<Result<List<Wallet>, ReceiveFailure>> execute({
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
    bool sync = false,
  }) async {
    try {
      return Ok(
        await _getWalletsUsecase.execute(
          onlyDefaults: onlyDefaults,
          onlyBitcoin: onlyBitcoin,
          onlyLiquid: onlyLiquid,
          sync: sync,
        ),
      );
    } on Object catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.severe(
        message: 'Failed to load wallets for receive',
        error: e,
        trace: st,
      );
      return Err(ReceiveUnexpectedFailure(e.toString()));
    }
  }
}
