import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Derives one of our own addresses, used as the stand-in a payin is priced
/// against before the order has one.
class GetPayPayinAddressUsecase {
  final GetAddressAtIndexUsecase _getAddressAtIndexUsecase;

  const GetPayPayinAddressUsecase({required this._getAddressAtIndexUsecase});

  @useResult
  Future<Result<String, PayFailure>> execute({
    required String walletId,
    int index = 0,
  }) async {
    try {
      final address = await _getAddressAtIndexUsecase.execute(
        walletId: walletId,
        index: index,
      );
      return Ok(address.address);
    } catch (e, st) {
      log.severe(
        message: 'Failed to derive the pay fee-estimation address',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
  }
}
