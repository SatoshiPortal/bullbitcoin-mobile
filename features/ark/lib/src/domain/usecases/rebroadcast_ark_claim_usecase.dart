import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_claim_recovery_selection.dart';
import '../ark_failure.dart';
import '../repositories/ark_repository.dart';

/// Explicit foreground action on a saved review. No quote, build, drain,
/// signature or new operation: native submission reconciles before same bytes.
final class RebroadcastArkClaimUsecase {
  final ArkRepository _repository;
  const RebroadcastArkClaimUsecase(this._repository);

  Future<Result<ArkOperation, ArkFailure>> execute(
    ArkAccountId account,
    ArkClaimRecoverySelection selection,
  ) {
    if (account != selection.account) {
      return Future.value(const Err(ArkInvalidRequestFailure()));
    }
    if (!NetworkCapabilities.supports(account.network, NetworkCapability.ark)) {
      return Future.value(const Err(ArkNetworkUnavailableFailure()));
    }
    return _repository.submit(
      account,
      ArkSubmission.rebroadcastClaim(
        operationId: selection.operation.id,
        expectedTxid: selection.summary.txid,
      ),
    );
  }
}
