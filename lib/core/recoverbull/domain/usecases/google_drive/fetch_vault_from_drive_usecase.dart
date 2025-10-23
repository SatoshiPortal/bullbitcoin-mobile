import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';

class FetchVaultFromDriveUsecase {
  final GoogleDriveRepository _driveRepository;

  FetchVaultFromDriveUsecase({required GoogleDriveRepository driveRepository})
    : _driveRepository = driveRepository;

  Future<String> execute(DriveFileMetadata driveFileMetadata) async {
    try {
      final content = await _driveRepository.fetchFileContent(
        driveFileMetadata.id,
      );
      return content;
    } catch (e) {
      rethrow;
    }
  }
}
