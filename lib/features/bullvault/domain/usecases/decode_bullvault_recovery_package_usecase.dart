import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

final class DecodeBullVaultRecoveryPackageUsecase {
  final BullVaultRepository _repository;

  const DecodeBullVaultRecoveryPackageUsecase(this._repository);

  @useResult
  Result<BullVaultRecoveryPackage, BullVaultFailure> execute(String source) =>
      _repository.decodeRecoveryPackage(source);
}
