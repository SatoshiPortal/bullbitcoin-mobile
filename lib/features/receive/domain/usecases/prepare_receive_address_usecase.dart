import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:meta/meta.dart';

/// Receive-owned boundary for the shared address use-case, which still throws
/// (a `GetReceiveAddressException`).
class PrepareReceiveAddressUsecase {
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;

  const PrepareReceiveAddressUsecase(this._getReceiveAddressUsecase);

  @useResult
  Future<Result<WalletAddress, ReceiveFailure>> execute({
    required String walletId,
    bool generateNew = false,
  }) async {
    try {
      return Ok(
        await _getReceiveAddressUsecase.execute(
          walletId: walletId,
          generateNew: generateNew,
        ),
      );
    } on Object catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.severe(
        message: 'Failed to prepare a receive address',
        error: e,
        trace: st,
      );
      return Err(ReceiveAddressUnavailableFailure(e.toString()));
    }
  }
}
