import '../../repositories/google_drive_repository.dart';
import '../../recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class ConnectToGoogleDriveUsecase {
  final GoogleDriveRepository _driveRepository;

  ConnectToGoogleDriveUsecase({required this._driveRepository});

  Future<Result<Null, RecoverBullFailure>> execute() {
    return _driveRepository.connect();
  }
}
