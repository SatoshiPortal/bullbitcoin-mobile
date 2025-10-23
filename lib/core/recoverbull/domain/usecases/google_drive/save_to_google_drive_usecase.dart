import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';

class SaveToGoogleDriveUsecase {
  final GoogleDriveRepository _driveRepository;

  SaveToGoogleDriveUsecase({required GoogleDriveRepository driveRepository})
    : _driveRepository = driveRepository;

  Future<void> execute(String content) async {
    try {
      await _driveRepository.storeBackup(content);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
