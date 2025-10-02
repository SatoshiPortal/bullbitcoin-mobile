import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class SaveFileToSystemUsecase {
  final fileSystemRepository = FileSystemRepository();

  SaveFileToSystemUsecase();

  Future<void> execute({
    required String content,
    required String filename,
  }) async {
    try {
      await fileSystemRepository.saveFile(content, filename);
    } catch (e) {
      log.severe(e);
      rethrow;
    }
  }
}
