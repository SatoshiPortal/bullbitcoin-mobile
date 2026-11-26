import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart' show ArkStageBudget;
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import '../ark_claim_recovery_selection.dart';
import '../repositories/ark_repository.dart';
import '../repositories/ark_account_registry_repository.dart';
import 'read_ark_usecase.dart';
import 'update_ark_expiry_warning_usecase.dart';

/// The host opens an existing-only native client with stage-budget admission.
/// This usecase awaits its pass through settlement: no timeout can close the
/// native writer while an admitted stage is still running.
final class RunArkBackgroundUsecase {
  final SynchronizeArkUsecase _synchronize;
  final UpdateArkExpiryWarningUsecase _warnings;
  const RunArkBackgroundUsecase(this._synchronize, this._warnings);

  Future<Result<void, ArkFailure>> execute(ArkAccountId account) async {
    switch (await _synchronize.execute(account, renew: true)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.snapshot.account != account) {
          return const Err(ArkUnexpectedFailure());
        }
        if (!value.completedStages.contains(ArkStage.vtxos) ||
            value.failedStageKinds.contains(ArkStage.vtxos)) {
          return const Err(ArkServiceUnavailableFailure());
        }
        final reminder = await _warnings.execute(value.snapshot);
        if (reminder case Err(:final failure)) return Err(failure);
        return value.failedStages.isEmpty && value.failedStageKinds.isEmpty
            ? const Ok(null)
            : const Err(ArkServiceUnavailableFailure());
    }
  }
}

/// Keyless journal selection only. Package admission revalidates saved bytes;
/// a summary is not authority to construct, sign or change a claim.
final class RunArkSavedClaimsUsecase {
  final ArkRepository _repository;
  final ArkStageBudget _budget;
  const RunArkSavedClaimsUsecase(this._repository, this._budget);

  Future<Result<void, ArkFailure>> execute(ArkAccountId account) async {
    if (!_budget.mayAdmitNextStage) return const Err(ArkOperationBusyFailure());
    if (!NetworkCapabilities.supports(account.network, NetworkCapability.ark)) {
      return const Err(ArkNetworkUnavailableFailure());
    }
    final ArkSnapshot snapshot;
    switch (await _repository.read(account)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        snapshot = value;
    }
    if (snapshot.account != account) return const Err(ArkUnexpectedFailure());
    ArkFailure? failed;
    for (final operation in snapshot.operations) {
      if (!_budget.mayAdmitNextStage) {
        return const Err(ArkOperationBusyFailure());
      }
      if (operation.kind != ArkOperationKind.claim ||
          operation.claimRecovery == null ||
          operation.status == ArkOperationStatus.succeeded ||
          operation.status == ArkOperationStatus.failed ||
          operation.status == ArkOperationStatus.conflicted) {
        continue;
      }
      switch (ArkClaimRecoverySelection.fromSnapshot(
        account,
        operation.id,
        snapshot,
      )) {
        case Err(:final failure):
          failed ??= failure;
        case Ok(:final value):
          final result = await _repository.submit(
            account,
            ArkSubmission.rebroadcastClaim(
              operationId: value.operation.id,
              expectedTxid: value.summary.txid,
            ),
          );
          if (result case Err(:final failure)) failed ??= failure;
      }
    }
    return failed == null ? const Ok(null) : Err(failed);
  }
}

/// Persisted protected accounts include funded-off accounts. Delivery precedes
/// keyed renewal, and neither lane's failure skips the other admitted lane.
final class RunArkBackgroundTaskUsecase {
  final ArkAccountRegistryRepository _protectedAccounts;
  final ArkStageBudget _budget;
  final RunArkSavedClaimsUsecase _savedDelivery;
  final RunArkBackgroundUsecase _renew;

  /// False in the headless task: no seed is read in the background, so only
  /// saved claims run there. Renewal happens in the foreground.
  final bool renewalEnabled;
  const RunArkBackgroundTaskUsecase(
    this._protectedAccounts,
    this._budget,
    this._savedDelivery,
    this._renew, {
    this.renewalEnabled = true,
  });

  Future<Result<void, ArkFailure>> execute() async {
    if (!_budget.mayAdmitNextStage) return const Err(ArkOperationBusyFailure());
    final List<ArkAccountConfig> accounts;
    switch (await _protectedAccounts.list()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        accounts = value;
    }
    ArkFailure? failed;
    for (final config in accounts) {
      if (!_budget.mayAdmitNextStage) {
        return const Err(ArkOperationBusyFailure());
      }
      final delivery = await _savedDelivery.execute(config.id);
      if (delivery case Err(:final failure)) failed ??= failure;
    }
    // No account's keyed work can strand another account's saved delivery.
    for (final config
        in renewalEnabled ? accounts : const <ArkAccountConfig>[]) {
      if (!_budget.mayAdmitNextStage) {
        return const Err(ArkOperationBusyFailure());
      }
      final renew = await _renew.execute(config.id);
      if (renew case Err(:final failure)) failed ??= failure;
    }
    return failed == null ? const Ok(null) : Err(failed);
  }
}
