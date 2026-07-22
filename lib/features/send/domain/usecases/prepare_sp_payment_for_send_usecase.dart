import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';

export 'package:bb_mobile/features/sp/public/sp_facade.dart'
    show SpFailure, SpRecipient, SpTxDraft;

class PrepareSpPaymentForSendUsecase {
  final SpFacade _spFacade;

  PrepareSpPaymentForSendUsecase(this._spFacade);

  Future<Result<SpTxDraft, SpFailure>> execute({
    required List<SpRecipient> recipients,
    required BigInt feerateSatVb,
  }) => _spFacade.preparePayment(
    recipients: recipients,
    feerateSatVb: feerateSatVb,
  );
}
