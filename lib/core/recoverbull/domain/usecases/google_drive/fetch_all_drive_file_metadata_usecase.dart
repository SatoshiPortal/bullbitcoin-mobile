import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';

class FetchAllDriveFileMetadataUsecase {
  final GoogleDriveRepository _driveRepository;

  FetchAllDriveFileMetadataUsecase({required this._driveRepository});

  Future<Result<List<DriveFileMetadata>, RecoverBullCoreFailure>>
  execute() async {
    final connected = await _driveRepository.connect();
    if (connected case Err(:final failure)) return Err(failure);
    return _driveRepository.fetchAllMetadata();
  }
}
