import '../../data/file_system_repository.dart';
import '../recoverbull_failure.dart';
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
