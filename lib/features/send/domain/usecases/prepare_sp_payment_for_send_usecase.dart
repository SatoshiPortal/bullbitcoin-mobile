import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart';
import 'package:send/send.dart';
import 'package:bb_mobile/features/send/domain/sp_failure_mapping.dart';
import 'package:silent/silent.dart';

class PrepareSpPaymentForSendUsecase {
  final Silent _silent;

  PrepareSpPaymentForSendUsecase(this._silent);

  Future<Result<SilentTxDraft, SendFailure>> execute({
    required List<SilentRecipient> recipients,
    required NetworkFee? fee,
  }) async {
    if (fee is AbsoluteFee) {
      return const Err(
        SendTransactionBuildFailure(
          'Silent Payments requires a fee rate, not an absolute fee',
        ),
      );
    }
    return (await _silent.preparePayment(
      recipients: recipients,
      feerateSatVb: _feerateSatVb(fee),
    )).mapErr(
      (failure) =>
          failure.toSendFailure() ??
          SendTransactionBuildFailure(failure.logMessage),
    );
  }

  // SP spends at a whole sat/vB rate and never below the one sat/vB relay
  // floor, including when no fee has been picked yet.
  BigInt _feerateSatVb(NetworkFee? fee) {
    if (fee == null) return BigInt.one;
    final rate = fee.value.round();
    return BigInt.from(rate < 1 ? 1 : rate);
  }
}
