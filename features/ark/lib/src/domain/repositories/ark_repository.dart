import 'package:ark/ark.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';

abstract interface class ArkRepository {
  @useResult
  Future<Result<ArkSnapshot, ArkFailure>> create(ArkAccountConfig config);
  @useResult
  Future<Result<ArkSnapshot, ArkFailure>> read(ArkAccountId account);
  Stream<Result<ArkSnapshot, ArkFailure>> watch(ArkAccountId account);
  @useResult
  Future<Result<ArkPassOutcome, ArkFailure>> synchronize(
    ArkAccountId account, {
    required bool renew,
  });
  @useResult
  Future<Result<ArkQuote, ArkFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  );
  @useResult
  Future<Result<ArkOperation, ArkFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  );
  @useResult
  Future<Result<ArkReceiveDestination, ArkFailure>> receive(
    ArkAccountId account,
    ArkReceiveRequest request,
  );
}
