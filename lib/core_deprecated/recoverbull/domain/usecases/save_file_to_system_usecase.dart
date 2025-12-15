import 'package:bb_mobile/core_deprecated/recoverbull/data/repository/file_system_repository.dart';

class SaveFileToSystemUsecase {
  final fileSystemRepository = FileSystemRepository();

  SaveFileToSystemUsecase();

  Future<void> execute({
    required String content,
    required String filename,
  }) async {
    await fileSystemRepository.saveFile(content, filename);
  }
}
