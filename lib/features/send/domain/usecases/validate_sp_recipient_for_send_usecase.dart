import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/sp_failure_mapping.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:primitives/primitives.dart';

export 'package:bb_mobile/features/sp/public/sp_facade.dart'
    show SpAddress, SpRecipient, SpRecipientSp, SpRecipientStandard;

class ValidateSpRecipientForSendUsecase {
  final SpFacade _spFacade;

  ValidateSpRecipientForSendUsecase(this._spFacade);

  Future<Result<SpRecipient, SendFailure>> execute({
    required String input,
    required Sats amountSat,
    required bool isMax,
  }) async {
    final result = await _spFacade.validateRecipient(
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
