import 'package:bb_mobile/core_deprecated/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/domain/entity/encrypted_vault.dart';

class FetchVaultFromDriveUsecase {
  final GoogleDriveRepository _driveRepository;

  FetchVaultFromDriveUsecase({required GoogleDriveRepository driveRepository})
    : _driveRepository = driveRepository;

  Future<EncryptedVault> execute(DriveFileMetadata driveFileMetadata) async {
    try {
      final content = await _driveRepository.fetchFileContent(
        driveFileMetadata.id,
      );
      return EncryptedVault(file: content);
    } catch (e) {
      rethrow;
    }
  }
}
