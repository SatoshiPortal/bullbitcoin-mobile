import 'package:bb_mobile/_core/domain/repositories/google_drive_repository.dart';

class DisconnectFromGoogleDriveUseCase {
  final GoogleDriveRepository _repository;

  DisconnectFromGoogleDriveUseCase(this._repository);

  Future<void> execute() async {
    try {
      await _repository.disconnect();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
