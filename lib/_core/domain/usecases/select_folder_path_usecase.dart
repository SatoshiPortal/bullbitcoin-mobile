import 'package:bb_mobile/_core/domain/repositories/file_system_repository.dart';

class SelectFolderPathUsecase {
  final FileSystemRepository _fileRepository;

  SelectFolderPathUsecase(this._fileRepository);

  Future<String?> execute() async {
    return await _fileRepository.getDirectoryPath();
  }
}
