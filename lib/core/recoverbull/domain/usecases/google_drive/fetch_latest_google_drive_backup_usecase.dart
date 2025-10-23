import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';

class FetchLatestGoogleDriveVaultUsecase {
  final _repository = GoogleDriveRepository();

  FetchLatestGoogleDriveVaultUsecase();

  Future<({String content, String fileName})> execute() async {
    try {
      final availableBackups = await _repository.fetchAllMetadata();
      final latestBackup = availableBackups.reduce((a, b) {
        final aTime = a.createdTime;
        final bTime = b.createdTime;
        return aTime.compareTo(bTime) > 0 ? a : b;
      });
      final content = await _repository.fetchFileContent(latestBackup.id);
      return (content: content, fileName: latestBackup.name);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
