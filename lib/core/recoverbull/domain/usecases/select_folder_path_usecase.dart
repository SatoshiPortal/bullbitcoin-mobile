import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';

class SelectFolderPathUsecase {
  final FileSystemRepository _fileRepository;

  SelectFolderPathUsecase(this._fileRepository);

  Future<String?> execute() async {
    return await _fileRepository.getDirectoryPath();
  }
}
