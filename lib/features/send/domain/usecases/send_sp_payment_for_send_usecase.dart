import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';

export 'package:bb_mobile/features/sp/public/sp_facade.dart' show SpTxDraft;

class SendSpPaymentForSendUsecase {
  final SpFacade _spFacade;

  SendSpPaymentForSendUsecase(this._spFacade);

  /// Every failure here happened while broadcasting, so none of them maps to a
  /// more specific send failure.
  Future<Result<String, SendFailure>> execute({
    required SpTxDraft draft,
  }) async => (await _spFacade.sendPayment(draft: draft)).mapErr(
    (failure) => SendTransactionConfirmationFailure(
      isBroadcastFailure: true,
      logMessage: failure.logMessage,
    ),
  );
}
