import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import '../repositories/ark_repository.dart';

final class ReadArkUsecase {
  final ArkRepository _repository;
  const ReadArkUsecase(this._repository);
  Future<Result<ArkSnapshot, ArkFailure>> execute(ArkAccountId account) =>
      _repository.read(account);
  Stream<Result<ArkSnapshot, ArkFailure>> watch(ArkAccountId account) =>
      _repository.watch(account);
}

/// Protective renewal remains available while new Ark routes are switched off.
/// Native code owns single-writer admission, reconciliation and round exclusion.
final class SynchronizeArkUsecase {
  final ArkRepository _repository;
  const SynchronizeArkUsecase(this._repository);
  Future<Result<ArkPassOutcome, ArkFailure>> execute(
    ArkAccountId account, {
    required bool renew,
  }) => _repository.synchronize(account, renew: renew);
}
