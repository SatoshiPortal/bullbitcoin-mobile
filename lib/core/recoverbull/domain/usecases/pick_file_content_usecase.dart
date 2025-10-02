import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';

class PickFileContentUsecase {
  final _fileRepository = FileSystemRepository();

  PickFileContentUsecase();

  Future<String> execute() async => await _fileRepository.pickFile();
}
