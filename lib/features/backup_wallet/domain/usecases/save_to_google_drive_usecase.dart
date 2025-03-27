import 'package:bb_mobile/core/domain/repositories/google_drive_repository.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class SaveToGoogleDriveUsecase {
  final GoogleDriveRepository _repository;

  SaveToGoogleDriveUsecase(this._repository);

  Future<void> execute(String content) async {
    try {
      await _repository.storeBackup(content);
    } catch (e) {
      debugPrint('Failed to google drive: $e');
      throw Exception("Failed to save google drive");
    }
  }
}
