import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;

class FetchAllGoogleDriveBackupsUsecase {
  final GoogleDriveRepository _repository;

  FetchAllGoogleDriveBackupsUsecase(this._repository);

  Future<List<DriveFile>> execute() async {
    try {
      return await _repository.fetchBackupFiles();
    } catch (e) {
      log.severe('FetchAllGoogleDriveBackupsUsecaseException: $e');
      throw FetchAllGoogleDriveBackupsUsecaseException(e.toString());
    }
  }
}

class FetchAllGoogleDriveBackupsUsecaseException implements Exception {
  final String message;
  FetchAllGoogleDriveBackupsUsecaseException(this.message);
}
