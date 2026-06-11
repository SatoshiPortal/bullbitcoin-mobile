import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';

class ConnectToGoogleDriveUsecase {
  final GoogleDriveRepository _driveRepository;

  ConnectToGoogleDriveUsecase({required this._driveRepository});

  Future<void> execute() async {
    try {
      await _driveRepository.connect();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
