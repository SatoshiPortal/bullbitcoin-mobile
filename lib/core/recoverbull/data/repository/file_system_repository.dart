import 'package:bb_mobile/core/recoverbull/data/datasources/file_storage_datasource.dart';

class FileSystemRepository {
  final _fileStorageDataSource = FileStorageDatasource();

  FileSystemRepository();

  Future<String> pickFile({List<String>? extensions}) async {
    final file = await _fileStorageDataSource.pickFile(extensions: extensions);
    final fileContent = await file.readAsString();
    return fileContent;
  }

  Future<void> saveFile(String content, String filename) async {
    await _fileStorageDataSource.saveFile(content, filename);
  }
}
