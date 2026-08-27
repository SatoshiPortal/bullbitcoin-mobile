import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';

class FetchVaultFromDriveUsecase {
  final GoogleDriveRepository _driveRepository;

  FetchVaultFromDriveUsecase({required this._driveRepository});

  Future<Result<EncryptedVault, RecoverBullCoreFailure>> execute(
    DriveFileMetadata driveFileMetadata,
  ) {
    return _driveRepository.fetchVault(driveFileMetadata.id);
  }
}
