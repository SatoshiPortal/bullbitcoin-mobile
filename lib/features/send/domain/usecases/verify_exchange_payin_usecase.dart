import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class VerifyExchangePayinUsecase {
  final WalletRepository _walletRepository;

  VerifyExchangePayinUsecase(this._walletRepository);

  @useResult
  Future<Result<void, SendFailure>> execute({
    required String psbtOrPset,
    required OrderSwapRecord record,
    required String walletId,
  }) async {
    final order = record.order;
    if (order == null) {
      log.severe(
        error: 'Exchange order is missing, cannot verify the payin',
        trace: StackTrace.current,
      );
      return const Err(SendUnexpectedFailure('Exchange order is missing'));
    }

    try {
      final actualAmount = await _walletRepository.getAmountSentToAddress(
        psbtOrPset: psbtOrPset,
        address: order.payinAddress,
        walletId: walletId,
      );
      if (actualAmount != order.payinAmountSat.toInt()) {
        log.severe(
          error: 'Exchange payin output does not match the pinned order',
          trace: StackTrace.current,
        );
        return const Err(
          SendExchangeOrderMismatchFailure(
            'Exchange payin output does not match the pinned order',
          ),
        );
      }
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to verify Exchange payin',
        error: e,
        trace: st,
      );
      return Err(
        SendUnexpectedFailure(
          'Failed to verify Exchange payin: ${e.runtimeType}',
        ),
      );
    }
  }
}
