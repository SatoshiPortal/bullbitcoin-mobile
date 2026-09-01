import 'package:bull_recoverbull/src/data/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class DeleteDriveFileUsecase {
  final GoogleDriveRepository _driveRepository;

  DeleteDriveFileUsecase({required this._driveRepository});

  Future<Result<Null, RecoverBullFailure>> execute(String fileId) {
    return _driveRepository.trash(fileId);
  }
}
