import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_failure.dart';
import '../domain/repositories/ark_repository.dart';

final class ArkRepositoryImpl implements ArkRepository {
  final ArkClient _client;
  const ArkRepositoryImpl(this._client);

  Future<Result<T, ArkFailure>> _run<T>(
    Future<Result<T, ArkWalletFailure>> Function() action,
  ) async {
    try {
      return (await action()).mapErr(_map);
    } on Exception catch (_) {
      return const Err(ArkUnexpectedFailure());
    }
  }

  @override
  Future<Result<ArkSnapshot, ArkFailure>> create(ArkAccountConfig config) =>
      _run(() => _client.create(config));
  @override
  Future<Result<ArkSnapshot, ArkFailure>> read(ArkAccountId account) =>
      _run(() => _client.read(account));
  @override
  Stream<Result<ArkSnapshot, ArkFailure>> watch(ArkAccountId account) async* {
    try {
      await for (final result in _client.watch(account)) {
        yield result.mapErr(_map);
      }
    } on Exception catch (_) {
      yield const Err(ArkUnexpectedFailure());
    }
  }

  @override
  Future<Result<ArkPassOutcome, ArkFailure>> synchronize(
    ArkAccountId account, {
    required bool renew,
  }) => _run(() => _client.synchronize(account, renew: renew));
  @override
  Future<Result<ArkQuote, ArkFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  ) => _run(() => _client.quote(account, request));
  @override
  Future<Result<ArkOperation, ArkFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  ) async {
    // A thrown transport exception after admission is not evidence of failure.
    // Preserve operation identity so the UI reconciles instead of replaying.
    try {
      return (await _client.submit(account, submission)).mapErr(_map);
    } on Exception catch (_) {
      final operationId = switch (submission) {
        ArkRebroadcastClaim(:final operationId) ||
        ArkConfirmQuote(:final operationId) ||
        ArkBoardFunding(:final operationId) ||
        ArkRegisterBoard(:final operationId) => operationId,
      };
      return Err(ArkSubmissionUncertainFailure(operationId));
    }
  }

  @override
  Future<Result<ArkReceiveDestination, ArkFailure>> receive(
    ArkAccountId account,
    ArkReceiveRequest request,
  ) => _run(() => _client.receive(account, request));
  @override
  Future<Result<ArkOperation?, ArkFailure>> progressStartedExits(
    ArkAccountId account,
  ) => _run(() => _client.progressStartedExits(account));

  // A claim interrupted after admission is journalled; saved-claim delivery
  // reconciles it on the next pass, so a lost reply is not a lost claim.
  @override
  Future<Result<List<ArkOperation>, ArkFailure>> claimAuthorized(
    ArkAccountId account,
  ) => _run(() => _client.claimAuthorized(account));

  @override
  Future<Result<DateTime, ArkFailure>> nextRound(ArkAccountId account) =>
      _run(() => _client.nextRound(account));

  static ArkFailure _map(ArkWalletFailure failure) => switch (failure) {
    ArkUnavailableFailure() => const ArkServiceUnavailableFailure(),
    ArkWriterBusyFailure() => const ArkOperationBusyFailure(),
    ArkStorageFailure() => const ArkFeatureStorageFailure(),
    ArkValidationFailure() => const ArkInvalidRequestFailure(),
    ArkStaleQuoteFailure() => const ArkReviewExpiredFailure(),
    ArkRecoveryRequiredFailure() => const ArkAccountRecoveryFailure(),
    ArkInsufficientFundsFailure() => const ArkPaymentInsufficientFundsFailure(),
    ArkExitFeesShortFailure(:final missing, :final incoming) =>
      ArkExitAwaitingFeesFailure(missing: missing, incoming: incoming),
    ArkOutcomeUnknownFailure(:final operationId) =>
      ArkSubmissionUncertainFailure(operationId),
    ArkNativeFailure() => const ArkUnexpectedFailure(),
  };
}
