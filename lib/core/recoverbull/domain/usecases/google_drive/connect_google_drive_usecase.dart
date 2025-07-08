import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';

class ConnectToGoogleDriveUsecase {
  final GoogleDriveRepository _repository;

  ConnectToGoogleDriveUsecase(this._repository);

  Future<void> execute() async {
    try {
      await _repository.connect();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}

class ConnectToGoogleDriveSilentlyUsecase {
  final GoogleDriveRepository _repository;

  ConnectToGoogleDriveSilentlyUsecase(this._repository);

  Future<void> execute() async {
    try {
      await _repository.connectSilently();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
