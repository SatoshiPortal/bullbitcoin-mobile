import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

/// Scripted fake at the real package boundary, for feature usecase/UI tests.
final class FakeArkClient implements ArkClient {
  final List<String> calls = [];
  final List<Object> arguments = [];
  late Result<ArkSnapshot, ArkWalletFailure> snapshot;
  late Result<ArkPassOutcome, ArkWalletFailure> pass;
  late Result<ArkQuote, ArkWalletFailure> quoted;
  late Result<ArkOperation, ArkWalletFailure> submitted;
  late Result<ArkReceiveDestination, ArkWalletFailure> destination;
  Stream<Result<ArkSnapshot, ArkWalletFailure>> changes = const Stream.empty();
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
  Future<void> close() async {
    calls.add('close');
  }
}
