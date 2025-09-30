import 'package:bb_mobile/core/recoverbull/data/datasources/file_storage_datasource.dart';

class FileSystemRepository {
  final _fileStorageDataSource = FileStorageDatasource();

  FileSystemRepository();

  Future<String> pickFile() async {
    final file = await _fileStorageDataSource.pickFile();
    final fileContent = await file.readAsString();
    return fileContent;
  }

  Future<String?> getDirectoryPath() async {
    return await _fileStorageDataSource.pickDirectory();
  }

  Future<void> shareText(String text) async {
    await _fileStorageDataSource.shareText(text);
  }
}
