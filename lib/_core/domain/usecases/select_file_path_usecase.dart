import 'package:bb_mobile/_core/domain/repositories/file_system_repository.dart';

class SelectFileFromPathUsecase {
  final FileSystemRepository _fileRepository;

  SelectFileFromPathUsecase(this._fileRepository);

  Future<String?> execute() async {
    return await _fileRepository.pickFile();
  }
}
