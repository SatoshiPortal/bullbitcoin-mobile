import 'package:bull_recoverbull/src/data/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class ConnectToGoogleDriveUsecase {
  final GoogleDriveRepository _driveRepository;

  ConnectToGoogleDriveUsecase({required this._driveRepository});

  Future<Result<Null, RecoverBullCoreFailure>> execute() {
    return _driveRepository.connect();
  }
}
