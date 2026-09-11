import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_bitcoin_signing_plan_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_pending_bitcoin_transaction_usecase.dart';
import 'package:meta/meta.dart';

typedef RefreshedBitcoinSigningPlan = ({
  BitcoinSigningPlanDetails details,
  PendingBitcoinTransaction? transaction,
});

class RefreshBitcoinSigningPlanUsecase {
  final ValidatePendingBitcoinTransactionUsecase _validate;
  final GetBitcoinSigningPlanUsecase _getPlan;

  const RefreshBitcoinSigningPlanUsecase(this._validate, this._getPlan);

  @useResult
  Future<Result<RefreshedBitcoinSigningPlan, SendFailure>> execute({
    required Wallet wallet,
    required String? psbt,
    required BitcoinPolicySelection selection,
    required Set<String> satisfiedPreimageKeys,
    required bool isSigningSession,
    PendingBitcoinTransaction? pending,
  }) async {
    PendingBitcoinTransaction? validatedTransaction;
    if (pending != null) {
      switch (await _validate.execute(
        pending,
        satisfiedPreimageKeys: satisfiedPreimageKeys,
      )) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: final validated):
          validatedTransaction = validated.transaction;
          if (validated.details case final details?) {
            return Ok((details: details, transaction: validatedTransaction));
          }
      }
    }
    final result = await _getPlan.execute(
      wallet: wallet,
      psbt: psbt,
      selection: selection,
      satisfiedPreimageKeys: satisfiedPreimageKeys,
      allowSpentWalletInputs: isSigningSession,
      allowFrozenWalletInputs: isSigningSession,
    );
    return result.map(
      (details) => (details: details, transaction: validatedTransaction),
    );
  }
}
