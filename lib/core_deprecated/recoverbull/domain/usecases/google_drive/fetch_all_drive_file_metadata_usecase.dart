import 'package:bb_mobile/core_deprecated/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/domain/entity/drive_file_metadata.dart';

class FetchAllDriveFileMetadataUsecase {
  final GoogleDriveRepository _driveRepository;

  FetchAllDriveFileMetadataUsecase({
    required GoogleDriveRepository driveRepository,
  }) : _driveRepository = driveRepository;

  Future<List<DriveFileMetadata>> execute() async {
    try {
      await _driveRepository.connect();
      return await _driveRepository.fetchAllMetadata();
    } catch (e) {
      rethrow;
    }
  }
}
