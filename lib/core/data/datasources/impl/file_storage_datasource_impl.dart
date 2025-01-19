import 'dart:io';

import 'package:bb_mobile/core/data/datasources/file_storage_data_source.dart';
import 'package:path_provider/path_provider.dart';

class FileStorageDataSourceImpl implements FileStorageDataSource {
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
