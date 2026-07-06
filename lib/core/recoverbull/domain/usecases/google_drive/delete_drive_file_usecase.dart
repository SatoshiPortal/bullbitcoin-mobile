import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';

class DeleteDriveFileUsecase {
  final GoogleDriveRepository _driveRepository;

  DeleteDriveFileUsecase({required this._driveRepository});

  Future<Result<Null, RecoverBullCoreFailure>> execute(String fileId) {
    return _driveRepository.trash(fileId);
  }
}
