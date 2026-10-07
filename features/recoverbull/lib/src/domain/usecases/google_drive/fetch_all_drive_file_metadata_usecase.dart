import '../../repositories/google_drive_repository.dart';
import '../../entities/drive_file_metadata.dart';
import '../../recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class FetchAllDriveFileMetadataUsecase {
  final GoogleDriveRepository _driveRepository;

  FetchAllDriveFileMetadataUsecase({required this._driveRepository});

  Future<Result<List<DriveFileMetadata>, RecoverBullFailure>> execute() async {
    final connected = await _driveRepository.connect();
    if (connected case Err(:final failure)) return Err(failure);
    return _driveRepository.fetchAllMetadata();
  }
}
