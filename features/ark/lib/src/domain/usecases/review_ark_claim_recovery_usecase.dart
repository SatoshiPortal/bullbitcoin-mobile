import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_claim_recovery_selection.dart';
import '../ark_failure.dart';
import '../repositories/ark_repository.dart';

final class ReviewArkClaimRecoveryUsecase {
  final ArkRepository _repository;
  const ReviewArkClaimRecoveryUsecase(this._repository);

  Future<Result<ArkClaimRecoverySelection, ArkFailure>> execute(
    ArkAccountId account,
    String operationId,
  ) async {
    if (operationId.trim().isEmpty) {
      return const Err(ArkInvalidRequestFailure());
    }
    if (!NetworkCapabilities.supports(account.network, NetworkCapability.ark)) {
      return const Err(ArkNetworkUnavailableFailure());
    }
    switch (await _repository.read(account)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return ArkClaimRecoverySelection.fromSnapshot(
          account,
          operationId,
          value,
        );
    }
  }
}
