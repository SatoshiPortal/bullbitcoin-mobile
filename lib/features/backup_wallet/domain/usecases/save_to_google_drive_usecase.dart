import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class SaveToGoogleDriveUsecase {
  final GoogleDriveRepository _repository;

  SaveToGoogleDriveUsecase(this._repository);

  Future<void> execute(String content) async {
    try {
      await _repository.store(content);
    } catch (e) {
      log.severe('Failed to google drive: $e');
      throw Exception("Failed to save google drive");
    }
  }
}
