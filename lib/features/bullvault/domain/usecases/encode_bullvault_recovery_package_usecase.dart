import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';

class EncodeBullVaultRecoveryPackageUsecase {
  final BullVaultRepository _repository;

  const EncodeBullVaultRecoveryPackageUsecase(this._repository);

  String execute(BullVaultRecoveryPackage recoveryPackage) =>
      _repository.encodeRecoveryPackage(recoveryPackage);
}
