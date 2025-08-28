import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';

class FetchAllDriveBackupsUsecase {
  final GoogleDriveRepository _driveRepository;

  FetchAllDriveBackupsUsecase(this._driveRepository);

  Future<List<DriveFileMetadata>> execute() async {
    try {
      await _driveRepository.connect();
      return await _driveRepository.fetchAllMetadata();
    } catch (e) {
      rethrow;
    }
  }
}
