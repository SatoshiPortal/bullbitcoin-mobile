import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';

class ExportDriveFileUsecase {
  final GoogleDriveRepository _driveRepository;
  final _fileSystemRepository = FileSystemRepository();

  ExportDriveFileUsecase({required GoogleDriveRepository driveRepository})
    : _driveRepository = driveRepository;

  Future<void> execute(DriveFileMetadata fileMetadata) async {
    try {
      final content = await _driveRepository.fetchFileContent(fileMetadata.id);
      await _fileSystemRepository.saveFile(content, fileMetadata.name);
    } catch (e) {
      rethrow;
    }
  }
}
