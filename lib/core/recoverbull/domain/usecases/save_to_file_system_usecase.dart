import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class SaveToFileSystemUsecase {
  final FileSystemRepository fileSystemRepository;

  SaveToFileSystemUsecase(this.fileSystemRepository);

  Future<void> execute(String content) async {
    try {
      await fileSystemRepository.shareText(content);
    } catch (e) {
      log.severe('Failed to save file to system: $e');
      throw Exception('Failed to save file to system');
    }
  }
}
