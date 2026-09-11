import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class BroadcastPayPayinUsecase {
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTransactionUsecase;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTransactionUsecase;

  const BroadcastPayPayinUsecase({
    required this._broadcastBitcoinTransactionUsecase,
    required this._broadcastLiquidTransactionUsecase,
  });

  @useResult
  Future<Result<String, PayFailure>> bitcoin(
    String transaction, {
    required bool isPsbt,
  }) async {
    try {
      return Ok(
        await _broadcastBitcoinTransactionUsecase.execute(
          transaction,
          isPsbt: isPsbt,
        ),
      );
    } catch (e, st) {
      log.severe(
        message: 'Failed to broadcast the Bitcoin pay payin',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
  }

  @useResult
  Future<Result<String, PayFailure>> liquid(String signedPset) async {
    try {
      return Ok(await _broadcastLiquidTransactionUsecase.execute(signedPset));
    } catch (e, st) {
      log.severe(
        message: 'Failed to broadcast the Liquid pay payin',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
  }
}
