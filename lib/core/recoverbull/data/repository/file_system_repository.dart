import 'dart:io';

import 'package:bb_mobile/core/recoverbull/data/datasources/file_storage_datasource.dart';

class FileSystemRepository {
  final FileStorageDatasource _fileStorageDataSource;

  FileSystemRepository(this._fileStorageDataSource);

  Future<String?> pickFile() async {
    final file = await _fileStorageDataSource.pickFile();
    return file?.path;
  }

  Future<File> saveFile(File file, String content) async {
    return await _fileStorageDataSource.saveToFile(file, content);
  }

  Future<void> deleteFile(String path) async {
    await _fileStorageDataSource.deleteFile(path);
  }

  Future<String> getAppDirectory() async {
    return await _fileStorageDataSource.getAppDirectory();
  }

  Future<String> getDownloadDirectory() async {
    return await _fileStorageDataSource.getDownloadDirectory();
  }

  Future<String?> getDirectoryPath() async {
    return await _fileStorageDataSource.getDirectoryPath();
  }
}
