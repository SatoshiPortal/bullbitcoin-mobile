import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

/// Scripted fake at the real package boundary, for feature usecase/UI tests.
class FakeArkClient implements ArkClient {
  final List<String> calls = [];
  final List<Object> arguments = [];
  late Result<ArkSnapshot, ArkWalletFailure> snapshot;
  late Result<ArkPassOutcome, ArkWalletFailure> pass;
  late Result<ArkQuote, ArkWalletFailure> quoted;
  late Result<ArkOperation, ArkWalletFailure> submitted;
  late Result<ArkReceiveDestination, ArkWalletFailure> destination;
  Result<DateTime, ArkWalletFailure> nextRoundStart = const Err(
    ArkUnavailableFailure(),
  );
  Stream<Result<ArkSnapshot, ArkWalletFailure>> changes = const Stream.empty();
  Result<List<ArkOperation>, ArkWalletFailure> claimed = const Ok([]);
  Result<ArkOperation?, ArkWalletFailure> progressed = const Ok(null);
  @override
  Future<Result<ArkOperation?, ArkWalletFailure>> progressStartedExits(
    ArkAccountId account,
  ) async {
    calls.add('progressStartedExits');
    arguments.add(account);
    return progressed;
  }

  @override
  Future<Result<List<ArkOperation>, ArkWalletFailure>> claimAuthorized(
    ArkAccountId account,
  ) async {
    calls.add('claimAuthorized');
    arguments.add(account);
    return claimed;
  }

  @override
  Future<Result<ArkSnapshot, ArkWalletFailure>> create(
    ArkAccountConfig config,
  ) async {
    calls.add('create');
    arguments.add(config);
    return snapshot;
  }

  @override
  Future<Result<ArkSnapshot, ArkWalletFailure>> read(
    ArkAccountId account,
  ) async {
    calls.add('read');
    arguments.add(account);
    return snapshot;
  }

  @override
  Stream<Result<ArkSnapshot, ArkWalletFailure>> watch(ArkAccountId account) {
    arguments.add(account);
    return changes;
  }

  @override
  Future<Result<ArkPassOutcome, ArkWalletFailure>> synchronize(
    ArkAccountId account, {
    required bool renew,
  }) async {
    calls.add(renew ? 'renew' : 'sync');
    arguments.add((account, renew));
    return pass;
  }

  @override
  Future<Result<ArkQuote, ArkWalletFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  ) async {
    calls.add('quote');
    arguments.add((account, request));
    return quoted;
  }

  @override
  Future<Result<ArkOperation, ArkWalletFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  ) async {
    calls.add('submit');
    arguments.add((account, submission));
    return submitted;
  }

  @override
  Future<Result<ArkReceiveDestination, ArkWalletFailure>> receive(
    ArkAccountId account,
    ArkReceiveRequest request,
  ) async {
    calls.add('receive');
    arguments.add((account, request));
    return destination;
  }

  @override
  Future<Result<DateTime, ArkWalletFailure>> nextRound(
    ArkAccountId account,
  ) async {
    calls.add('next-round');
    arguments.add(account);
    return nextRoundStart;
  }

  @override
  Future<void> close() async {
    calls.add('close');
  }
}
