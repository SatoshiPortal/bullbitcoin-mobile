import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

/// The client the headless Ark task is given (D105): the three operations it
/// needs and no other.
///
/// - [read], the journal projection that selects saved claims;
/// - [submit] of a saved-claim rebroadcast only: bytes already signed, no seed;
/// - [synchronize] with renewal, the refresh. A synchronization without
///   renewal is refused: the background lane opens a native session only to
///   refresh.
///
/// Everything else (creating, quoting, receiving, exits, next round, any other
/// submission) is refused with [ArkRenewalNotPermittedFailure] before it
/// reaches the inner client, so the task cannot turn this client into a general
/// native session.
ArkClient confineArkClient(ArkClient inner) => _ConfinedArkClient(inner);

final class _ConfinedArkClient implements ArkClient {
  final ArkClient _inner;
  const _ConfinedArkClient(this._inner);

  static const _refused = ArkRenewalNotPermittedFailure();

  @override
  Future<Result<ArkSnapshot, ArkWalletFailure>> read(ArkAccountId account) =>
      _inner.read(account);

  @override
  Future<Result<ArkPassOutcome, ArkWalletFailure>> synchronize(
    ArkAccountId account, {
    required bool renew,
  }) async =>
      renew ? _inner.synchronize(account, renew: true) : const Err(_refused);

  @override
  Future<Result<ArkOperation, ArkWalletFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  ) async => submission is ArkRebroadcastClaim
      ? _inner.submit(account, submission)
      : const Err(_refused);

  @override
  Future<void> close() => _inner.close();

  @override
  Future<Result<ArkSnapshot, ArkWalletFailure>> create(
    ArkAccountConfig config,
  ) async => const Err(_refused);

  @override
  Stream<Result<ArkSnapshot, ArkWalletFailure>> watch(ArkAccountId account) =>
      const Stream.empty();

  @override
  Future<Result<ArkQuote, ArkWalletFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  ) async => const Err(_refused);

  @override
  Future<Result<ArkOperation?, ArkWalletFailure>> progressStartedExits(
    ArkAccountId account,
  ) async => const Err(_refused);

  @override
  Future<Result<List<ArkOperation>, ArkWalletFailure>> claimAuthorized(
    ArkAccountId account,
  ) async => const Err(_refused);

  @override
  Future<Result<ArkReceiveDestination, ArkWalletFailure>> receive(
    ArkAccountId account,
    ArkReceiveRequest request,
  ) async => const Err(_refused);

  @override
  Future<Result<DateTime, ArkWalletFailure>> nextRound(
    ArkAccountId account,
  ) async => const Err(_refused);
}
