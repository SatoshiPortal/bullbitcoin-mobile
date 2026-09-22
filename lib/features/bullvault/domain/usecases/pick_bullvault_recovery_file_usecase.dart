import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

class PickBullVaultRecoveryFileUsecase {
  final BullVaultRepository _repository;

  const PickBullVaultRecoveryFileUsecase(this._repository);

  @useResult
  Future<Result<String?, BullVaultFailure>> execute() =>
      _repository.pickRecoveryFile();
}
