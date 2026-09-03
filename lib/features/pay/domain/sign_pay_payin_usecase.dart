import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Signs the pay payin on either network.
class SignPayPayinUsecase {
  final SignBitcoinTxUsecase _signBitcoinTxUsecase;
  final SignLiquidTxUsecase _signLiquidTxUsecase;

  const SignPayPayinUsecase({
    required this._signBitcoinTxUsecase,
    required this._signLiquidTxUsecase,
  });

  /// Signs [psbt] and reports the signed transaction with its vsize.
  @useResult
  Future<Result<({String signedPsbt, int txSize}), PayFailure>> bitcoin({
    required String psbt,
    required String walletId,
  }) async {
    try {
      final signed = await _signBitcoinTxUsecase.execute(
        psbt: psbt,
        walletId: walletId,
      );
      return Ok((signedPsbt: signed.signedPsbt, txSize: signed.txSize));
    } catch (e, st) {
      log.severe(
        message: 'Failed to sign the Bitcoin pay payin',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
  }

  @useResult
  Future<Result<String, PayFailure>> liquid({
    required String pset,
    required String walletId,
  }) async {
    try {
      final signedPset = await _signLiquidTxUsecase.execute(
        pset: pset,
        walletId: walletId,
      );
      return Ok(signedPset);
    } catch (e, st) {
      log.severe(
        message: 'Failed to sign the Liquid pay payin',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
  }
}
