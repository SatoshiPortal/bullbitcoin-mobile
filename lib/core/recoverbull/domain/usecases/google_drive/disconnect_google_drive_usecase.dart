import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';

class DisconnectFromGoogleDriveUsecase {
  final GoogleDriveRepository _driveRepository;

  DisconnectFromGoogleDriveUsecase({
    required GoogleDriveRepository driveRepository,
  }) : _driveRepository = driveRepository;

  Future<void> execute() async {
    try {
      await _driveRepository.disconnect();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
