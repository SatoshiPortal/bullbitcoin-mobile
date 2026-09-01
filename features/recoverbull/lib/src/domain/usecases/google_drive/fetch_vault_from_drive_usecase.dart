import '../../../data/google_drive_repository.dart';
import '../../entities/drive_file_metadata.dart';
import '../../entities/encrypted_vault.dart';
import '../../recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class FetchVaultFromDriveUsecase {
  final GoogleDriveRepository _driveRepository;

  FetchVaultFromDriveUsecase({required this._driveRepository});

  Future<Result<EncryptedVault, RecoverBullFailure>> execute(
    DriveFileMetadata driveFileMetadata,
  ) {
    return _driveRepository.fetchVault(driveFileMetadata.id);
  }
}
