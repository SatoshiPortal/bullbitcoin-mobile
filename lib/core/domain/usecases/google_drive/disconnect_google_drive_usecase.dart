import 'package:bb_mobile/core/domain/repositories/google_drive_repository.dart';

class DisconnectFromGoogleDriveUsecase {
  final GoogleDriveRepository _repository;

  DisconnectFromGoogleDriveUsecase(this._repository);

  Future<void> execute() async {
    try {
      await _repository.disconnect();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
