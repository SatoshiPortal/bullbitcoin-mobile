import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;

class FetchGoogleDriveBackupContentUsecase {
  final GoogleDriveRepository _repository;

  FetchGoogleDriveBackupContentUsecase(this._repository);

  Future<BackupInfo> execute(String driveFileId) async {
    try {
      final backupContent = await _repository.fetchBackupContent(driveFileId);

      final backupInfo = BackupInfo(backupFile: backupContent);
      if (backupInfo.isCorrupted) {
        throw Exception('Backup is corrupted');
      }
      return backupInfo;
    } catch (e) {
      log.severe('FetchGoogleDriveBackupContentUsecase error: $e');
      throw Exception('Error fetching backup content');
    }
  }
}
