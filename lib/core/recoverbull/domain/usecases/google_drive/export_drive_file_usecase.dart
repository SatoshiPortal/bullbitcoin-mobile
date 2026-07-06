import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';

class ExportDriveFileUsecase {
  final GoogleDriveRepository _driveRepository;
  final FileSystemRepository _fileSystemRepository;

  ExportDriveFileUsecase({
    required this._driveRepository,
    required this._fileSystemRepository,
  });

  Future<Result<Null, RecoverBullCoreFailure>> execute(
    DriveFileMetadata fileMetadata,
  ) async {
    final content = await _driveRepository.fetchRawFile(fileMetadata.id);
    return switch (content) {
      Ok(:final value) => await _fileSystemRepository.saveFile(
        value,
        fileMetadata.name,
      ),
      Err(:final failure) => Err(failure),
    };
  }
}
