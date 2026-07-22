import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';

export 'package:bb_mobile/features/sp/public/sp_facade.dart'
    show SpFailure, SpRecipient;

class ValidateSpRecipientForSendUsecase {
  final SpFacade _spFacade;

  ValidateSpRecipientForSendUsecase(this._spFacade);

  Result<SpRecipient, SpFailure> execute({
    required String input,
    required BigInt amountSat,
    required bool isMax,
  }) => _spFacade.validateRecipient(
    input: input,
    amountSat: amountSat,
    isMax: isMax,
  );
}
