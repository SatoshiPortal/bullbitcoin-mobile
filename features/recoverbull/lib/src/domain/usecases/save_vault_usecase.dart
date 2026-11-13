import 'package:primitives/primitives.dart';

import '../entities/encrypted_vault.dart';
import '../entities/vault_provider.dart';
import '../recoverbull_failure.dart';
import '../repositories/google_drive_repository.dart';
import '../repositories/vault_file_repository.dart';

final class SaveVaultUsecase {
  final VaultFileRepository _files;
  final GoogleDriveRepository _drive;

  const SaveVaultUsecase(this._files, this._drive);

  Future<Result<void, RecoverBullFailure>> execute(
    EncryptedVault vault,
    VaultProvider provider,
  ) async {
    if (provider != VaultProvider.googleDrive) return _files.save(vault);
    switch (await _drive.connect()) {
      case Err(:final failure):
        return Err(failure);
      case Ok():
        return _drive.store(vault);
    }
  }
}
