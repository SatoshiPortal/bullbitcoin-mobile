import '../../../data/google_drive_repository.dart';
import '../../recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class DeleteDriveFileUsecase {
  final GoogleDriveRepository _driveRepository;

  DeleteDriveFileUsecase({required this._driveRepository});

  Future<Result<Null, RecoverBullFailure>> execute(String fileId) {
    return _driveRepository.trash(fileId);
  }
}
