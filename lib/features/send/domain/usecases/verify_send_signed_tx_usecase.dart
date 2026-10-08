import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/verify_signed_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:meta/meta.dart';

class VerifySendSignedTxUsecase {
  final VerifySignedTxUsecase _verifySignedTxUsecase;

  VerifySendSignedTxUsecase(this._verifySignedTxUsecase);

  @useResult
  Future<Result<void, SendFailure>> execute({
    required String unsignedPsbt,
    required String signedTransaction,
  }) async {
    final result = await _verifySignedTxUsecase.execute(
      unsignedPsbt: unsignedPsbt,
      signedTransaction: signedTransaction,
    );
    return result.mapErr(
      (failure) =>
          SendTransactionConfirmationFailure(logMessage: failure.logMessage),
    );
  }
}
