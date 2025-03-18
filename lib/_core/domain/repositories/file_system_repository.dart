import 'dart:io';

abstract class FileSystemRepository {
  Future<String?> pickFile();
  Future<File> saveFile(File file, String content);
  Future<void> deleteFile(String path);
  Future<String> getAppDirectory();
  Future<String> getDownloadDirectory();
}
