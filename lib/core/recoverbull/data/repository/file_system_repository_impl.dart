import 'dart:io';

import 'package:bb_mobile/core/recoverbull/data/datasources/file_storage_datasource.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/file_system_repository.dart';

class FileSystemRepositoryImpl implements FileSystemRepository {
  final FileStorageDatasource _fileStorageDataSource;

  FileSystemRepositoryImpl(this._fileStorageDataSource);

  @override
  Future<String?> pickFile() async {
    final file = await _fileStorageDataSource.pickFile();
    return file?.path;
  }

  @override
  Future<File> saveFile(File file, String content) async {
    return await _fileStorageDataSource.saveToFile(file, content);
  }

  @override
  Future<void> deleteFile(String path) async {
    await _fileStorageDataSource.deleteFile(path);
  }

  @override
  Future<String> getAppDirectory() async {
    return await _fileStorageDataSource.getAppDirectory();
  }

  @override
  Future<String> getDownloadDirectory() async {
    return await _fileStorageDataSource.getDownloadDirectory();
  }

  @override
  Future<String?> getDirectoryPath() async {
    return await _fileStorageDataSource.getDirectoryPath();
  }
}
