import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';

export 'package:bb_mobile/features/sp/public/sp_facade.dart'
    show SpFailure, SpTxDraft;

class SendSpPaymentForSendUsecase {
  final SpFacade _spFacade;

  SendSpPaymentForSendUsecase(this._spFacade);

  Future<Result<String, SpFailure>> execute({required SpTxDraft draft}) =>
      _spFacade.sendPayment(draft: draft);
}
