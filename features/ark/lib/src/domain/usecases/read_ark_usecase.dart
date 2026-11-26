import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import '../repositories/ark_repository.dart';

final class ReadArkUsecase {
  final ArkRepository _repository;
  const ReadArkUsecase(this._repository);
  Future<Result<ArkSnapshot, ArkFailure>> execute(ArkAccountId account) async =>
      _bind(account, await _repository.read(account));
  Stream<Result<ArkSnapshot, ArkFailure>> watch(ArkAccountId account) =>
      _repository.watch(account).map((result) => _bind(account, result));

  static Result<ArkSnapshot, ArkFailure> _bind(
    ArkAccountId account,
    Result<ArkSnapshot, ArkFailure> result,
  ) {
    if (result case Ok(:final value) when value.account != account) {
      return const Err(ArkUnexpectedFailure());
    }
    return result;
  }
}

/// Protective renewal remains available while new Ark routes are switched off.
/// Native code owns single-writer admission, reconciliation and round exclusion.
final class SynchronizeArkUsecase {
  final ArkRepository _repository;
  const SynchronizeArkUsecase(this._repository);
  Future<Result<ArkPassOutcome, ArkFailure>> execute(
    ArkAccountId account, {
    required bool renew,
  }) async {
    final result = await _repository.synchronize(account, renew: renew);
    if (result case Ok(:final value) when value.snapshot.account != account) {
      return const Err(ArkUnexpectedFailure());
    }
    return result;
  }
}
