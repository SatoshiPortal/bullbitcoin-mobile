import 'package:bull_recoverbull/src/data/file_system_repository.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class SaveFileToSystemUsecase {
  final FileSystemRepository _fileSystemRepository;

  SaveFileToSystemUsecase({required this._fileSystemRepository});

  Future<Result<Null, RecoverBullFailure>> execute({
    required String content,
    required String filename,
  }) {
    return _fileSystemRepository.saveFile(content, filename);
  }
}
