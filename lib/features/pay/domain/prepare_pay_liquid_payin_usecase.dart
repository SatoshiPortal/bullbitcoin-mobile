import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/consolidation_required_exception.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Builds the unsigned PSET for a Liquid pay payin.
class PreparePayLiquidPayinUsecase {
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;

  const PreparePayLiquidPayinUsecase({required this._prepareLiquidSendUsecase});

  @useResult
  Future<Result<String, PayFailure>> execute({
    required String walletId,
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
  }) async {
    try {
      final pset = await _prepareLiquidSendUsecase.execute(
        walletId: walletId,
        address: address,
        amountSat: amountSat,
        feeRate: feeRate,
        drain: drain,
      );
      return Ok(pset);
    } on InsufficientFundsException catch (e, st) {
      log.warning('Liquid pay payin is short of funds', error: e, trace: st);
      return Err(
        PayInsufficientBalanceFailure(
          requiredAmountSat: amountSat ?? 0,
          logMessage: e.message,
        ),
      );
    } on NoSpendableUtxoException catch (e, st) {
      log.warning('Liquid wallet has no spendable utxo', error: e, trace: st);
      return Err(
        PayInsufficientBalanceFailure(
          requiredAmountSat: amountSat ?? 0,
          logMessage: e.message,
        ),
      );
    } on ConsolidationRequiredException catch (e, st) {
      log.warning('Liquid wallet needs consolidating', error: e, trace: st);
      return Err(PayUnexpectedFailure(e.message));
    } catch (e, st) {
      log.severe(
        message: 'Failed to build the Liquid pay payin',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
  }
}
