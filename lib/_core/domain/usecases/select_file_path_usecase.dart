import 'package:bb_mobile/_core/domain/repositories/file_system_repository.dart';

class SelectFilePathUsecase {
  final FileSystemRepository _fileRepository;

  SelectFilePathUsecase(this._fileRepository);

  Future<String?> execute() async {
    return await _fileRepository.pickFile();
  }
}
