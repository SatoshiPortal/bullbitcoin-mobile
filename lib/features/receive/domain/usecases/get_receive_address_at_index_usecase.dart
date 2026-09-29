import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:meta/meta.dart';

/// Receive-owned boundary for the shared address-at-index use-case, which
/// still throws (a `GetAddressAtIndexException`).
class GetReceiveAddressAtIndexUsecase {
  final GetAddressAtIndexUsecase _getAddressAtIndexUsecase;

  const GetReceiveAddressAtIndexUsecase(this._getAddressAtIndexUsecase);

  @useResult
  Future<Result<WalletAddress, ReceiveFailure>> execute({
    required String walletId,
    required int index,
  }) async {
    try {
      return Ok(
        await _getAddressAtIndexUsecase.execute(
          walletId: walletId,
          index: index,
        ),
      );
    } on Object catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.severe(
        message: 'Failed to read the receive address at index',
        error: e,
        trace: st,
      );
      return Err(ReceiveAddressUnavailableFailure(e.toString()));
    }
  }
}
