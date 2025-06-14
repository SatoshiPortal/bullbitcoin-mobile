import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';

class FetchLatestGoogleDriveBackupUsecase {
  final GoogleDriveRepository _repository;

  FetchLatestGoogleDriveBackupUsecase(this._repository);

  Future<String> execute() async {
    try {
      final availableBackups = await _repository.fetchBackupFiles();
      final latestBackup = availableBackups.reduce((a, b) {
        final aTime = a.createdTime;
        final bTime = b.createdTime;
        return aTime.compareTo(bTime) > 0 ? a : b;
      });
      return await _repository.fetchBackupContent(latestBackup.id);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
