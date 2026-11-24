import 'package:send/send.dart';
import 'package:bb_mobile/features/send/domain/sp_failure_mapping.dart';
import 'package:silent/silent.dart';
import 'package:primitives/primitives.dart';

class ValidateSpRecipientForSendUsecase {
  final Silent _silent;

  ValidateSpRecipientForSendUsecase(this._silent);

  Future<Result<SilentRecipient, SendFailure>> execute({
    required String input,
    required Sats amountSat,
    required bool isMax,
  }) async {
    final result = await _silent.validateRecipient(
      input: input,
      amountSat: amountSat,
      isMax: isMax,
    );
    return result.mapErr(
      (failure) =>
          failure.toSendFailure() ??
          SendInvalidPaymentRequestFailure(logMessage: failure.logMessage),
    );
  }
}
