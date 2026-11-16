import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../../ark.dart';

abstract interface class ArkClient {
  @useResult
  Future<Result<ArkSnapshot, ArkWalletFailure>> create(ArkAccountConfig config);
  @useResult
  Future<Result<ArkSnapshot, ArkWalletFailure>> read(ArkAccountId account);
  Stream<Result<ArkSnapshot, ArkWalletFailure>> watch(ArkAccountId account);
  @useResult
  Future<Result<ArkPassOutcome, ArkWalletFailure>> synchronize(
    ArkAccountId account, {
    required bool renew,
  });
  @useResult
  Future<Result<ArkQuote, ArkWalletFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  );
  @useResult
  Future<Result<ArkOperation, ArkWalletFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  );
  @useResult
  Future<Result<ArkReceiveDestination, ArkWalletFailure>> receive(
    ArkAccountId account,
    ArkReceiveRequest request,
  );
  Future<void> close();
}
