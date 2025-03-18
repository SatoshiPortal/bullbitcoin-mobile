import 'package:bb_mobile/_core/domain/repositories/google_drive_repository.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class SaveToGoogleDriveUseCase {
  final GoogleDriveRepository _repository;

  SaveToGoogleDriveUseCase(this._repository);

  Future<void> execute(String content) async {
    try {
      await _repository.storeBackup(content);
    } catch (e) {
      debugPrint('Failed to google drive: $e');
      throw Exception("Failed to save google drive");
    }
  }
}
