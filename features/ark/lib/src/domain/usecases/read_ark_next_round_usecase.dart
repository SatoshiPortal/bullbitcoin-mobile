import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import '../repositories/ark_repository.dart';

/// Asks the Ark server when its next round starts. Each call reaches the
/// server, so callers fetch once and count down locally.
final class ReadArkNextRoundUsecase {
  final ArkRepository _repository;
  const ReadArkNextRoundUsecase(this._repository);
  Future<Result<DateTime, ArkFailure>> execute(ArkAccountId account) =>
      _repository.nextRound(account);
}
