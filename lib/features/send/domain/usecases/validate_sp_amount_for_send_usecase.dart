import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/sp_failure_mapping.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:primitives/primitives.dart';

class ValidateSpAmountForSendUsecase {
  final SpFacade _spFacade;

  ValidateSpAmountForSendUsecase(this._spFacade);

  Result<Sats, SendFailure> execute(Sats amountSat) => _spFacade
      .validateAmount(amountSat)
      .mapErr(
        (failure) =>
            failure.toSendFailure() ??
            SendUnexpectedFailure(failure.logMessage),
      );
}
