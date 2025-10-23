import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';

class FetchAllDriveFileMetadataUsecase {
  final _driveRepository = GoogleDriveRepository();

  FetchAllDriveFileMetadataUsecase();

  Future<List<DriveFileMetadata>> execute() async {
    try {
      await _driveRepository.connect();
      return await _driveRepository.fetchAllMetadata();
    } catch (e) {
      rethrow;
    }
  }
}
