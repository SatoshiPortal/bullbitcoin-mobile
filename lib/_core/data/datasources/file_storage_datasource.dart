import 'dart:io';
import 'package:path_provider/path_provider.dart';

abstract class FileStorageDatasource {
  Future<File> saveToFile(File file, String value);
  Future<void> deleteFile(String filePath);
  Future<String> getAppDirectory();
  Future<String> getDownloadDirectory();
}

class FileStorageDatasourceImpl implements FileStorageDatasource {
  @override
  Future<File> saveToFile(File file, String value) async {
    return await file.writeAsString(value);
  }

  @override
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (file.existsSync()) {
      await file.delete(recursive: true);
    }
  }

  @override
  Future<String> getAppDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    return appDocDir.path;
  }

  @override
  Future<String> getDownloadDirectory() async {
    final downloadDir = await getDownloadsDirectory();
    if (downloadDir == null) {
      throw const FileSystemException('Could not get downloads directory');
    }
    return downloadDir.path;
  }
}
