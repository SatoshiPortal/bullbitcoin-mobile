import 'package:bb_mobile/_core/domain/repositories/google_drive_repository.dart';

class ConnectToGoogleDriveUseCase {
  final GoogleDriveRepository _repository;

  ConnectToGoogleDriveUseCase(this._repository);

  Future<void> execute() async {
    try {
      await _repository.connect();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
