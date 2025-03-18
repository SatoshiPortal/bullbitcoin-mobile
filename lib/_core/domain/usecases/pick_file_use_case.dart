import 'package:bb_mobile/_core/domain/repositories/file_system_repository.dart';

class SelectFilePathUseCase {
  final FileSystemRepository _fileRepository;

  SelectFilePathUseCase(this._fileRepository);

  Future<String?> execute() async {
    return await _fileRepository.pickFile();
  }
}
