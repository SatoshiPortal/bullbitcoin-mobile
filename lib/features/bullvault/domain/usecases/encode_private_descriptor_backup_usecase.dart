import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

/// Seals a vault's descriptor for its own cosigners.
///
/// Nothing here reads a private key, touches the network or writes anything: a
/// caller decides where the artifact goes.
final class EncodePrivateDescriptorBackupUsecase {
  final BullVaultRepository _repository;

  const EncodePrivateDescriptorBackupUsecase(this._repository);

  @useResult
  Future<Result<BullVaultDescriptorBackup, BullVaultFailure>> execute(
    String walletId,
  ) async {
    final stored = await _repository.getByWalletId(walletId);
    switch (stored) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        return const Err(BullVaultInvalidRecoveryFailure());
      case Ok(value: final record?):
        if (!record.deservesDescriptorBackup) {
          return const Err(BullVaultInvalidRecoveryFailure());
        }
        final policy = record.recoveryPackage.policy;
        return _repository.encodePrivateDescriptorBackup(
          descriptor: policy.descriptor,
          network: policy.network,
        );
    }
  }
}
