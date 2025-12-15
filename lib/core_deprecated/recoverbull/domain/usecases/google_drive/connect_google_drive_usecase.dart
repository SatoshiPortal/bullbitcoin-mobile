import 'package:bb_mobile/core_deprecated/recoverbull/data/repository/google_drive_repository.dart';

class ConnectToGoogleDriveUsecase {
  final GoogleDriveRepository _driveRepository;

  ConnectToGoogleDriveUsecase({required GoogleDriveRepository driveRepository})
    : _driveRepository = driveRepository;

  Future<void> execute() async {
    try {
      await _driveRepository.connect();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
