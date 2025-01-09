import 'dart:io';

abstract class FileStorageDataSource {
  Future<File> saveToFile(File file, String value);
  Future<void> deleteFile(String filePath);
  Future<String> getAppDirectory();
  Future<String> getDownloadDirectory();
}
