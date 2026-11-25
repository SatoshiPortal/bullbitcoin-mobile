import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/domain/sp_failure_mapping.dart';
import 'package:silent/silent.dart';
import 'package:primitives/primitives.dart';

class ValidateSpAmountForSendUsecase {
  final Silent _silent;

  ValidateSpAmountForSendUsecase(this._silent);

  Future<Result<Sats, SendFailure>> execute(Sats amountSat) async =>
      (await _silent.validateAmount(amountSat)).mapErr(
        (failure) =>
            failure.toSendFailure() ??
            SendUnexpectedFailure(failure.logMessage),
      );
}
