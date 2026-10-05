import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/sp_failure_mapping.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';

export 'package:bb_mobile/features/sp/public/sp_facade.dart'
    show SpAddress, SpRecipient, SpRecipientSp, SpRecipientStandard, SpTxDraft;

class PrepareSpPaymentForSendUsecase {
  final SpFacade _spFacade;

  PrepareSpPaymentForSendUsecase(this._spFacade);

  Future<Result<SpTxDraft, SendFailure>> execute({
    required List<SpRecipient> recipients,
    required NetworkFee? fee,
  }) async =>
      (await _spFacade.preparePayment(
        recipients: recipients,
        feerateSatVb: _feerateSatVb(fee),
      )).mapErr(
        (failure) =>
            failure.toSendFailure() ??
            SendTransactionBuildFailure(failure.logMessage),
      );

  // SP spends at a whole sat/vB rate and never below the one sat/vB relay
  // floor, including when no fee has been picked yet.
  BigInt _feerateSatVb(NetworkFee? fee) {
    if (fee == null) return BigInt.one;
    final rate = fee.value.round();
    return BigInt.from(rate < 1 ? 1 : rate);
  }
}
