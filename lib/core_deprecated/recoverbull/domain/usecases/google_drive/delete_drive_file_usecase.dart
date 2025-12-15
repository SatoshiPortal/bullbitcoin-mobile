import 'package:bb_mobile/core_deprecated/recoverbull/data/repository/google_drive_repository.dart';

class DeleteDriveFileUsecase {
  final GoogleDriveRepository _driveRepository;

  DeleteDriveFileUsecase({required GoogleDriveRepository driveRepository})
    : _driveRepository = driveRepository;

  Future<void> execute(String fileId) async {
    try {
      await _driveRepository.trash(fileId);
    } catch (e) {
      rethrow;
    }
  }
}
