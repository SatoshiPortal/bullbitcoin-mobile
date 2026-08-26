import 'package:bull_recoverbull/src/data/repository/file_system_repository.dart';
import 'package:bull_recoverbull/src/data/repository/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/entity/drive_file_metadata.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

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
