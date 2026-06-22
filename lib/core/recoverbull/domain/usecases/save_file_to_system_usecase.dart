import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';

class SaveFileToSystemUsecase {
  final FileSystemRepository _fileSystemRepository;

  SaveFileToSystemUsecase({required this._fileSystemRepository});

  Future<Result<Null, RecoverBullCoreFailure>> execute({
    required String content,
    required String filename,
  }) {
    return _fileSystemRepository.saveFile(content, filename);
  }
}
