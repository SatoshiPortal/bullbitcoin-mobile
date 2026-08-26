import 'package:bull_recoverbull/src/data/repository/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/entity/drive_file_metadata.dart';
import 'package:bull_recoverbull/src/domain/entity/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class FetchVaultFromDriveUsecase {
  final GoogleDriveRepository _driveRepository;

  FetchVaultFromDriveUsecase({required this._driveRepository});

  Future<Result<EncryptedVault, RecoverBullCoreFailure>> execute(
    DriveFileMetadata driveFileMetadata,
  ) {
    return _driveRepository.fetchVault(driveFileMetadata.id);
  }
}
