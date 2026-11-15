import 'package:primitives/primitives.dart';

import '../entities/drive_file_metadata.dart';
import '../entities/encrypted_vault.dart';
import '../recoverbull_failure.dart';
import '../repositories/google_drive_repository.dart';

final class ReadDriveVaultUsecase {
  final GoogleDriveRepository _drive;
  const ReadDriveVaultUsecase(this._drive);
  Future<Result<EncryptedVault, RecoverBullFailure>> execute(
    DriveFileMetadata file,
  ) => _drive.fetchVault(file);
}
