import 'package:primitives/primitives.dart';
import 'package:send/send.dart';
import 'package:silent/silent.dart';

class SendSpPaymentForSendUsecase {
  final Silent _silent;

  SendSpPaymentForSendUsecase(this._silent);

  /// Every failure here happened while broadcasting, so none of them maps to a
  /// more specific send failure.
  Future<Result<String, SendFailure>> execute({
    required SilentTxDraft draft,
  }) async => (await _silent.sendPayment(draft: draft)).mapErr(
    (failure) => SendTransactionConfirmationFailure(
      isBroadcastFailure: true,
      logMessage: failure.logMessage,
    ),
  );
}
