import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class ResolveWalletAddressUsecase {
  final GetReceiveAddressUsecase _getReceiveAddress;

  const ResolveWalletAddressUsecase(this._getReceiveAddress);

  @useResult
  Future<Result<String, LimitOrdersFailure>> execute(String walletId) async {
    try {
      final address = await _getReceiveAddress.execute(walletId: walletId);
      return Ok(address.address);
    } on Error {
      rethrow;
    } catch (e, st) {
      log.severe(
        message: 'Failed to derive a receive address for a limit order',
        error: e,
        trace: st,
      );
      return Err(LimitOrdersUnexpectedFailure('$e'));
    }
  }
}
