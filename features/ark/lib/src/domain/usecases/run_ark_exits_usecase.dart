import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart' show ArkStageBudget;
import 'package:primitives/primitives.dart';

import '../ark_exit_funding.dart';
import '../ark_failure.dart';
import '../ark_reserve_top_up_port.dart';
import '../repositories/ark_repository.dart';
import 'fund_ark_exit_fees_usecase.dart';

/// Claims finished emergency exits to the wallet chosen when they started,
/// within the fee ceiling recorded then. A claim above that ceiling is not
/// made and stays for the user to review.
final class ClaimArkExitsUsecase {
  final ArkRepository _repository;
  final ArkStageBudget _budget;

  const ClaimArkExitsUsecase(this._repository, this._budget);

  Future<Result<List<ArkOperation>, ArkFailure>> execute(
    ArkAccountId account,
  ) async {
    if (!_budget.mayAdmitNextStage) return const Err(ArkOperationBusyFailure());
    if (!NetworkCapabilities.supports(account.network, NetworkCapability.ark)) {
      return const Err(ArkNetworkUnavailableFailure());
    }
    return _repository.claimAuthorized(account);
  }
}

/// Moves started emergency exits forward: broadcasts the transactions that
/// are due, at the rate the native wallet picks, from the fee reserve. When
/// the reserve cannot pay yet, Secure Bitcoin funds it and the exit waits;
/// a wait is not a failure.
final class ProgressArkExitsUsecase {
  final ArkRepository _repository;
  final ArkStageBudget _budget;
  final ArkReserveTopUpPort? _topUp;
  final ArkExitFunding? _funding;

  const ProgressArkExitsUsecase(
    this._repository,
    this._budget, {
    this._topUp,
    this._funding,
  });

  Future<Result<ArkOperation?, ArkFailure>> execute(
    ArkAccountId account,
  ) async {
    if (!_budget.mayAdmitNextStage) return const Err(ArkOperationBusyFailure());
    if (!NetworkCapabilities.supports(account.network, NetworkCapability.ark)) {
      return const Err(ArkNetworkUnavailableFailure());
    }
    final progressed = await _repository.progressStartedExits(account);
    final topUp = _topUp, funding = _funding;
    switch (progressed) {
      case Err(failure: final ArkExitAwaitingFeesFailure short)
          when topUp != null && funding != null:
        final address = switch (await _repository.read(account)) {
          Ok(:final value) => value.reserveAddress,
          Err() => null,
        };
        final funded = await FundArkExitFeesUsecase(
          topUp,
          funding,
        ).execute(account, reserveAddress: address, short: short);
        return switch (funded) {
          Ok() => const Ok(null),
          Err(:final failure) => Err(failure),
        };
      case Ok():
        // Nothing waits for fees any more.
        funding?.waitFor(null);
      case Err():
    }
    return progressed;
  }
}
