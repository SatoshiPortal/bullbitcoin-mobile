import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';

class DisconnectFromGoogleDriveUsecase {
  final _repository = GoogleDriveRepository();

  DisconnectFromGoogleDriveUsecase();

  Future<void> execute() async {
    try {
      await _repository.disconnect();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
