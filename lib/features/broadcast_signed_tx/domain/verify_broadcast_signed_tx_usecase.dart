import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/verify_signed_tx_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:meta/meta.dart';

class VerifyBroadcastSignedTxUsecase {
  final VerifySignedTxUsecase _verifySignedTxUsecase;

  VerifyBroadcastSignedTxUsecase(this._verifySignedTxUsecase);

  @useResult
  Future<Result<void, BroadcastSignedTxFailure>> execute({
    required String unsignedPsbt,
    required String signedTransaction,
    bool isPsbt = false,
  }) async {
    final result = await _verifySignedTxUsecase.execute(
      unsignedPsbt: unsignedPsbt,
      signedTransaction: signedTransaction,
      isPsbt: isPsbt,
    );
    return result.mapErr(
      (failure) => InvalidTransactionFailure(failure.logMessage),
    );
  }
}
